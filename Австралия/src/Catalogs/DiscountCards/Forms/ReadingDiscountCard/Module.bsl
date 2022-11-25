
#Region Variables

&AtClient
Var PagesStack; // History of transitions to return by clicking Back

&AtClient
Var ReaderData; // Data cache is read by a magnetic card

#EndRegion

#Region CommonProceduresAndFunctions

// Function returns any attribute of discount card kind.
//
// Parameters:
//  Owner - CatalogRef.DiscountCardTypes - Kind of discount card.
//  Attribute - String - Owner attribute name.
//
&AtServerNoContext
Function GetDiscountCardKindAttribute(Owner, Attribute)

	Query = New Query;
	Query.Text = 
		"SELECT
		|	DiscountCardTypes."+Attribute+" AS Attribute
		|FROM
		|	Catalog.DiscountCardTypes AS DiscountCardTypes
		|WHERE
		|	DiscountCardTypes.Ref = &Ref";
	
	Query.SetParameter("Ref", Owner);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Attribute;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

#EndRegion

#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	Counterparty = Parameters.Counterparty;
	
	If DefaultCodeType.IsEmpty() Then
		DefaultCodeType = DiscountCardsServer.GetDiscountCardBasicCodeType();
	EndIf;
	
	DoNotUseManualInput = Parameters.DoNotUseManualInput;
	If DoNotUseManualInput Then
		Items.GroupCardCode.Visible = False;
	EndIf;
	
	If ValueIsFilled(Parameters.CardCode) Then
		
		// On reading several cards with this code were found in
		// list form, it is required to offer cards for user to choose.
		HandleReceivedCodeOnServer(Parameters.CardCode, Parameters.CodeType, True);
		Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupChoiceDiscountCard;
		
	Else
		
		If ValueIsFilled(DefaultCodeType) Then
			CodeType = DefaultCodeType;
		Else
			CodeType = Enums.CardCodesTypes.Barcode;
		EndIf;
		
		Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupReadingDiscountCard;
		
	EndIf;
	
	Items.ButtonPagesBack.CurrentPage = Items.ButtonPagesBack.ChildItems.ButtonBackIsAbsent;
	Items.ButtonPagesNext.CurrentPage = Items.ButtonPagesNext.ChildItems.DoneButton;
	
	If Not DoNotUseManualInput Then
		If Not ValueIsFilled(DefaultCodeType) Then
			Text = NStr("en = 'Read the discount card with barcode
			            |scanner (magnetic card reader) or enter code manually'; 
			            |ru = 'Считайте дисконтную карту при
			            |помощи сканера штрихкода (считывателя магнитных карт) или введите код вручную';
			            |pl = 'Sczytaj kartę rabatową skanerem kodów
			            |kreskowych (czytnikiem kart magnetycznych) lub wprowadź kod ręcznie';
			            |es_ES = 'Leer la tarjeta de descuentos con el escáner
			            |de código de barras (lector de tarjetas magnéticas), o introducir el código manualmente';
			            |es_CO = 'Leer la tarjeta de descuentos con el escáner
			            |de código de barras (lector de tarjetas magnéticas), o introducir el código manualmente';
			            |tr = 'İndirim kartını barkod
			            |tarayıcıyla (manyetik kart okuyucuyla) okutun veya kodu manuel olarak girin';
			            |it = 'Leggere la carta sconto con codice a barre
			            |scanner (lettore di schede magnetiche) o inserire manualmente il codice';
			            |de = 'Lesen Sie die Rabattkarte mit dem Barcode
			            |-Scanner (Magnetkartenleser) oder geben Sie den Code manuell ein'");
		ElsIf DefaultCodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode") Then
			Text = NStr("en = 'Read discount card with
			            |magnetic card reader or enter the magnetic code manually'; 
			            |ru = 'Считайте дисконтную
			            |карту при помощи считывателя магнитных карт или введите магнитный код вручную';
			            |pl = 'Sczytaj kartę rabatową
			            |czytnikiem kart magnetycznych lub wprowadź kod magnetyczny ręcznie';
			            |es_ES = 'Leer la tarjeta de descuentos con
			            |el lector de tarjetas magnéticas, o introducir el código magnético manualmente';
			            |es_CO = 'Leer la tarjeta de descuentos con
			            |el lector de tarjetas magnéticas, o introducir el código magnético manualmente';
			            |tr = 'İndirim kartını manyetik kart okuyucuyla okutun
			            |veya manyetik kodu manuel olarak girin';
			            |it = 'Leggere la carta sconto con
			            |un lettore di carte magnetiche o inserire il codice magnetico manualmente';
			            |de = 'Rabattkarte mit
			            |Magnetkartenleser lesen oder den Magnetcode manuell eingeben'");
		ElsIf DefaultCodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
			Text = NStr("en = 'Read the discount card with
			            |barcode scanner or enter barcode manually'; 
			            |ru = 'Считайте дисконтную карту
			            |при помощи сканера штрихкода или введите штрихкод вручную';
			            |pl = 'Sczytaj kartę rabatową
			            |skanerem kodów kreskowych lub wprowadź kod kreskowy ręcznie';
			            |es_ES = 'Leer la tarjeta de descuentos con
			            |el escáner de código de barras, o introducir el código de barras manualmente';
			            |es_CO = 'Leer la tarjeta de descuentos con
			            |el escáner de código de barras, o introducir el código de barras manualmente';
			            |tr = 'İndirim kartını barkod tarayıcıyla okutun
			            |veya barkodu manuel olarak girin';
			            |it = 'Leggere la carta sconto con
			            |uno scanner per codice a barre o inserire manualmente il codice a barre';
			            |de = 'Lesen Sie die Rabattkarte mit
			            |Barcode-Scanner oder geben Sie den Barcode manuell ein'");
		EndIf;
	Else
		If Not ValueIsFilled(DefaultCodeType) Then
			Text = NStr("en = 'Read the discount card with
			            |barcode scanner (magnetic card reader)'; 
			            |ru = 'Считайте дисконтную карту
			            |при помощи сканера штрихкода (считывателя магнитных карт)';
			            |pl = 'Sczytaj kartę rabatową
			            |skanerem kodów kreskowych (czytnikiem kart magnetycznych)';
			            |es_ES = 'Leer la tarjeta de descuentos con
			            |el escáner de código de barras (lector de tarjetas magnéticas)';
			            |es_CO = 'Leer la tarjeta de descuentos con
			            |el escáner de código de barras (lector de tarjetas magnéticas)';
			            |tr = 'İndirim kartını barkod tarayıcıyla
			            |(manyetik kart okuyucuyla) okutun';
			            |it = 'Leggere la carta sconto con
			            |uno scanner codice a barre (lettore di schede magnetiche)';
			            |de = 'Lesen Sie die Rabattkarte mit
			            |Barcode-Scanner (Magnetkartenleser)'");
		ElsIf DefaultCodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode") Then
			Text = NStr("en = 'Read discount card with
			            |magnetic cards reader'; 
			            |ru = 'Считайте дисконтную карту
			            |при помощи считывателя магнитных карт';
			            |pl = 'Sczytaj kartę rabatową
			            |czytnikiem kart magnetycznych';
			            |es_ES = 'Leer la tarjeta de descuentos con
			            |el lector de tarjetas magnéticas';
			            |es_CO = 'Leer la tarjeta de descuentos con
			            |el lector de tarjetas magnéticas';
			            |tr = 'İndirim kartını
			            |manyetik kart okuyucuyla okutun';
			            |it = 'Leggere la carta sconto con
			            |un lettore di carte magnetiche';
			            |de = 'Rabattkarte mit
			            |Magnetkartenleser lesen'");
		ElsIf DefaultCodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
			Text = NStr("en = 'Read the discount card
			            |with barcode scanner'; 
			            |ru = 'Считайте дисконтную
			            |карту при помощи сканера штрихкода';
			            |pl = 'Sczytaj kartę rabatową
			            |skanerem kodów kreskowych';
			            |es_ES = 'Leer la tarjeta de descuentos
			            |con el escáner de código de barras';
			            |es_CO = 'Leer la tarjeta de descuentos
			            |con el escáner de código de barras';
			            |tr = 'İndirim kartını
			            |barkod tarayıcıyla okutun';
			            |it = 'Leggere la carta sconto
			            |con uno scanner di codici a barre';
			            |de = 'Lesen Sie die Rabattkarte
			            |mit Barcode-Scanner'");
		EndIf;
	EndIf;
	LabelReadingDiscountCard = Text;

	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	// End Peripherals	
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	PagesStack = New Array;
	
	GenerateFormTitle();
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarcodeScanner,MagneticCardReader");
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
	If Source = "Peripherals" AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode");
			HandleBarcodes(DiscountCardsClient.ConvertDataFromScannerIntoArray(Parameter));
		ElsIf EventName ="TracksData" Then
			CodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode");
			HandleMagneticCardsReaderData(Parameter);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

// Procedure - event handler Clearing of item CodeType.
//
&AtClient
Procedure CodeTypeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

// Procedure - event handler Selection in values table FoundDiscountCards.
//
&AtClient
Procedure FoundDiscountCardsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	AttachIdleHandler("NextWaitHandler", 0.1, True);
	
EndProcedure

// Procedure - event handler OnChange of item DiscountCardKind.
//
&AtClient
Procedure KindDiscountCardOnChange(Item)
	
	ItemsVisibleSetupByCardKindOnServer();
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

// Procedure - event handler OnChange of item CardOwner.
//
&AtClient
Procedure CardOwnerOnChange(Item)
	
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

// Procedure - event handler OnChange of item CardCodeBarcode.
//
&AtClient
Procedure CardCodeBarcodeOnChange(Item)
	
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

// Procedure - event handler OnChange of item CardCodeMagnetic.
//
&AtClient
Procedure CardCodeMagneticOnChange(Item)
	
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

#EndRegion

#Region CommandHandlers

// Procedure - command handler Back of the form.
//
&AtClient
Procedure Back(Command)
	
	If PagesStack.Count() = 0 Then
		Return;
	EndIf;
	
	Items.Pages.CurrentPage = PagesStack[PagesStack.Count()-1];
	PagesStack.Delete(PagesStack.Count()-1);
	
	If PagesStack.Count() = 0 Then
		Items.ButtonPagesBack.CurrentPage = Items.ButtonPagesBack.ChildItems.ButtonBackIsAbsent;
	EndIf;
	
	Items.ButtonPagesNext.CurrentPage = Items.ButtonPagesNext.ChildItems.DoneButton;
	
	GenerateFormTitle();
	
EndProcedure

// Procedure - command handler Next of the form.
//
&AtClient
Procedure Next(Command)
	
	DetachIdleHandler("NextWaitHandler");
	
	ClearMessages();
	
	If Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupReadingDiscountCard Then
		
		If Not ValueIsFilled(CardCode) Then
			
			If CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
				MessageText = NStr("en = 'Barcode is not filled in.'; ru = 'Штрихкод не заполнен.';pl = 'Nie wprowadzono kodu kreskowego.';es_ES = 'Código de barras no se ha rellenado.';es_CO = 'Código de barras no se ha rellenado.';tr = 'Barkod doldurulmadı.';it = 'Il codice a barre non è compilato.';de = 'Barcode ist nicht ausgefüllt.'");
			Else
				MessageText = NStr("en = 'Magnetic code is not filled in.'; ru = 'Магнитный код не заполнен.';pl = 'Nie wprowadzono kodu magnetycznego.';es_ES = 'Código magnético no se ha rellenado.';es_CO = 'Código magnético no se ha rellenado.';tr = 'Manyetik kod doldurulmadı.';it = 'Codice magnetico non compilato.';de = 'Magnetcode ist nicht ausgefüllt.'");
			EndIf;
			
			CommonClientServer.MessageToUser(
				MessageText,
				,
				"CardCode");
			
			Return;
			
		EndIf;
		
		HandleReceivedCodeOnClient(CardCode, CodeType, False);
		
	ElsIf Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupChoiceDiscountCard Then
		
		CurrentData = Items.FoundDiscountCards.CurrentData;
		If CurrentData <> Undefined Then
			If ValueIsFilled(CurrentData.Ref) Then
				
				ProcessDiscountCardChoice(CurrentData);
				
			Else
				
				Object.Owner = CurrentData.CardKind;
				Object.CardOwner = Counterparty;
				Object.CardCodeMagnetic = CurrentData.MagneticCode;
				Object.CardCodeBarcode = CurrentData.Barcode;
				
				ItemsVisibleSetupByCardKindOnServer();
				Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
				
				GoToPage(Items.Pages.ChildItems.GroupDiscountCardCreate);	
				
			EndIf;
		EndIf;
		
	ElsIf Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupDiscountCardCreate Then
		
		If WriteDiscountCard() Then
		
			CloseParameters = New Structure("DiscountCard, DiscountCardRead", Object.Ref, False);
			Close(CloseParameters);
				
		EndIf;
		
	EndIf;
	
EndProcedure

// Function records current object and returns True if it is successfully recorded
//
&AtServer
Function WriteDiscountCard()

	If CheckFilling() Then
		Try
			Write();
			Return True;
		Except
			CommonClientServer.MessageToUser(ErrorDescription(), ThisObject); 
			Return False;
		EndTry;			
	Else
		Return False;
	EndIf;

EndFunction

// Procedure generates a form title depending on the current page and selected row in values table of
// found discount cards or discount cards kinds
//
&AtClient
Procedure GenerateFormTitle()
	
	If Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupReadingDiscountCard Then
		AutoTitle = False;
		Title = "Read discount card";
	ElsIf Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupChoiceDiscountCard Then
		AutoTitle = False;
		CurrentData = Items.FoundDiscountCards.CurrentData;
		If CurrentData <> Undefined Then
			If ValueIsFilled(CurrentData.Ref) Then
				Title = "Selection of discount card";
			Else
				Title = "Select a new discount card kind";
			EndIf;
		Else
			If FoundDiscountCards.Count() > 0 Then
				If ValueIsFilled(FoundDiscountCards[0].Ref) Then
					Title = "Selection of discount card";
				Else
					Title = "Select a new discount card kind";
				EndIf;
			Else
				Title = "Select a discount card \ new discount card kind";
			EndIf;
		EndIf;			
	ElsIf Items.Pages.CurrentPage = Items.Pages.ChildItems.GroupDiscountCardCreate Then
	    AutoTitle = True;
		Title = "";
	EndIf;
	
EndProcedure

// Procedure - command handler CopyBCInMC of the form.
//
&AtClient
Procedure CopyBCInMC(Command)
	
	Object.CardCodeMagnetic = Object.CardCodeBarcode;
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

// Procedure - command handler CopyMCInBC of the form.
//
&AtClient
Procedure CopyMCInBC(Command)
	
	Object.CardCodeBarcode = Object.CardCodeMagnetic;
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

&AtClient
Procedure Attachable_ExecuteOverriddenCommand(Command)
	
	
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure configures reference format and form filters.
//
&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FoundDiscountCards.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("FoundDiscountCards.Ref");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("FoundDiscountCards.AutomaticRegistrationOnFirstReading");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	Item.Appearance.SetParameterValue("BackColor", New Color());
	Item.Appearance.SetParameterValue("TextColor", WebColors.MediumGray);

EndProcedure

#Region BarcodesAndShopEquipment

// Procedure processes barcode data transmitted from form notifications data processor.
//
&AtClient
Procedure HandleBarcodes(BarcodesData)
	
	If Items.Pages.CurrentPage <> Items.Pages.ChildItems.GroupReadingDiscountCard Then
		Return;
	EndIf;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	HandleReceivedCodeOnClient(BarcodesArray[0].Barcode, PredefinedValue("Enum.CardCodesTypes.Barcode"), False);
	
EndProcedure

// Procedure processes data of magnetic card reader transmitted from the form notification data processor.
//
&AtClient
Procedure HandleMagneticCardsReaderData(Data)
	
	If Items.Pages.CurrentPage <> Items.Pages.ChildItems.GroupReadingDiscountCard Then
		Return;
	EndIf;
	
	ReaderData = Data;
	AttachIdleHandler("HandleReceivedCodeOnClientInWaitProcessor", 0.1, True);
	
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure GoToPage(Page)
	
	PagesStack.Add(Items.Pages.CurrentPage);
	Items.Pages.CurrentPage = Page;
	Items.ButtonPagesBack.CurrentPage = Items.ButtonPagesBack.ChildItems.ButtonBack;
	
	If Page = Items.Pages.ChildItems.GroupChoiceDiscountCard Then
		If CodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode") Then
			Text = NStr("en = 'Several discount cards with magnetic code ""%1"" are detected.
			            |Select suitable card.'; 
			            |ru = 'Обнаружено несколько дисконтных карт с магнитным кодом ""%1"".
			            |Выберите подходящую карту.';
			            |pl = 'Wykryto kilka kart rabatowych z kodem magnetycznym ""%1"".
			            |Wybierz odpowiednią kartę';
			            |es_ES = 'Varias tarjetas de descuentos con el código magnético ""%1"" se han detectado.
			            |Seleccionar la tarjeta conveniente.';
			            |es_CO = 'Varias tarjetas de descuentos con el código magnético ""%1"" se han detectado.
			            |Seleccionar la tarjeta conveniente.';
			            |tr = 'Birden fazla ""%1"" manyetik kodlu indirim kartı tespit edildi. 
			            |Uygun kartı seçin.';
			            |it = 'Sono rilevate diverse carte sconto con il codice magnetico ""%1"".
			            |Selezionare carta corretta.';
			            |de = 'Mehrere Rabattkarten mit Magnetcode ""%1"" werden erkannt.
			            |Wählen Sie die geeignete Karte aus.'");
		Else
			Text = NStr("en = 'Several discount cards with barcode ""%1"" are detected.
			            |Select suitable card.'; 
			            |ru = 'Обнаружено несколько дисконтных карт со штрихкодом ""%1"".
			            |Выберите подходящую карту.';
			            |pl = 'Wykryto kilka kart rabatowych z kodem kreskowym ""%1"".
			            |Wybierz odpowiednią kartę.';
			            |es_ES = 'Varias tarjetas de descuentos con el código de barras ""%1"" se han detectado.
			            |Seleccionar la tarjeta conveniente.';
			            |es_CO = 'Varias tarjetas de descuentos con el código de barras ""%1"" se han detectado.
			            |Seleccionar la tarjeta conveniente.';
			            |tr = '""%1"" barkodlu birden fazla indirim kartı tespit edildi.
			            |Uygun kartı seçin.';
			            |it = 'Sono rilevate diverse carte sconto con il codice a barre ""%1"".
			            |Selezionare carta corretta.';
			            |de = 'Mehrere Rabattkarten mit Barcode ""%1"" wurden erkannt.
			            |Wählen Sie die geeignete Karte aus.'");
		EndIf;
		LabelChoiceDiscountCard = StringFunctionsClientServer.SubstituteParametersToString(Text, CardCode);
	EndIf;
	
	GenerateFormTitle();
	
EndProcedure

// Function checks the magnetic code against the template and returns a list of DK, magnetic code or barcode.
//
&AtServer
Function HandleReceivedCodeOnServer(Data, CardCodeType, Preprocessing, ThereAreFoundCards = False)
	
	ThereAreFoundCards = False;
	
	SetPrivilegedMode(True);
	
	FoundDiscountCards.Clear();
	
	CodeType = CardCodeType;
	If CodeType = Enums.CardCodesTypes.MagneticCode Then
		// When function is called, the parameter "Preprocessing" shall be set to value False in order not to use magnetic card templates.
		// Line received by lines concatenation from all magnetic tracks will be used as a card code.
		// Majority of discount cards has only one track on which only card number is recorded in the format ";CardCode?".
		If Preprocessing Then
			CardCode = Data[0]; // Data of 3 magnetic card tracks. At this moment it is not used. Can be used if the card is not found.
			// When a card does not correspond to any template, the warning will appear but the button "Ready" in the form will
			// not be pressed.
			DiscountCards = DiscountCardsServerCall.FindDiscountCardsByDataFromMagneticCardReader(Data, CodeType);
		Else
			If TypeOf(Data) = Type("Array") Then
				CardCode = Data[0];
			Else
				CardCode = Data;
			EndIf;
			DiscountCardsServerCall.PrepareCardCodeByDefaultSettings(CardCode);
			DiscountCards = DiscountCardsServer.FindDiscountCardsByMagneticCode(CardCode);
		EndIf;
		
		Items.FoundDiscountCardsMagneticCode.Visible = True;
	Else       
		CardCode = Data;
		DiscountCards = DiscountCardsServerCall.FindDiscountCardsByBarcode(CardCode);
		
		Items.FoundDiscountCardsMagneticCode.Visible = False;
	EndIf;
	
	For Each TSRow In DiscountCards.RegisteredDiscountCards Do
		
		ThereAreFoundCards = True;
		
		NewRow = FoundDiscountCards.Add();
		FillPropertyValues(NewRow, TSRow);
		
		NewRow.Description = String(TSRow.Ref) + ?(ValueIsFilled(TSRow.Counterparty) AND ValueIsFilled(TSRow.Ref), StringFunctionsClientServer.SubstituteParametersToString(" " + NStr("en = 'Client: %1'; ru = 'Клиент: %1';pl = 'Klient: %1';es_ES = 'Cliente: %1';es_CO = 'Cliente: %1';tr = 'İstemci: %1';it = 'Client: %1';de = 'Klient: %1'"), String(TSRow.Counterparty)), "");
		
	EndDo;
	
	If DiscountCards.RegisteredDiscountCards.Count() = 0 Then
		For Each TSRow In DiscountCards.NotRegisteredDiscountCards Do
			
			NewRow = FoundDiscountCards.Add();
			FillPropertyValues(NewRow, TSRow);
			
			NewRow.Description = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Register a new card: %1'; ru = 'Зарегистрировать новую карту: %1';pl = 'Zarejestruj nową kartę: %1';es_ES = 'Registrar una tarjeta nueva: %1';es_CO = 'Registrar una tarjeta nueva: %1';tr = 'Yeni kartı kaydedin: %1';it = 'Registrare una nuova carta: %1';de = 'Registrieren Sie eine neue Karte: %1'"), String(TSRow.CardKind))+?(TSRow.ThisIsMembershipCard, " (Named, ", " (")+TSRow.CardType+")";
			
		EndDo;
	EndIf;
	
	Return FoundDiscountCards.Count() > 0;
	
EndFunction

// Function checks the magnetic code against the template and sets magnetic code or catalog item barcode.
//
&AtClient
Procedure HandleReceivedCodeOnClient(Data, ReceivedCodeType, Preprocessing)
	
	Var ThereAreFoundCards;
	
	Result = HandleReceivedCodeOnServer(Data, ReceivedCodeType, Preprocessing, ThereAreFoundCards);
	If Not Result Then
		
		If CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
			MessageText = NStr("en = 'Card with the ""%1"" barcode is not registered and there is no suitable discount card kind.'; ru = 'Карта со штрихкодом ""%1"" не зарегистрирована и нет ни одного подходящего вида дисконтных карт.';pl = 'Karta z kodem kreskowym ""%1"" nie jest zarejestrowana, nie ma odpowiedniego rodzaju karty rabatowej.';es_ES = 'Tarjeta con el ""%1"" código de barras no se ha registrado, y no hay un tipo de tarjeta de descuentos conveniente.';es_CO = 'Tarjeta con el ""%1"" código de barras no se ha registrado, y no hay un tipo de tarjeta de descuentos conveniente.';tr = '""%1"" barkodlu kart kayıtlı değil ve uygun bir indirim kartı türü yok.';it = 'La carta con codice a barre ""%1"" non è registrata e non ci sono tipologie di carte sconto accettabili.';de = 'Karte mit dem ""%1"" Barcode ist nicht registriert und es gibt keine passende Rabattkartenart.'");
		Else
			MessageText = NStr("en = 'Card with the ""%1"" magnetic code is not registered and there is no suitable discount card kind.'; ru = 'Карта с магнитным кодом ""%1"" не зарегистрирована и нет ни одного подходящего вида дисконтных карт.';pl = 'Karta z kodem magnetycznym ""%1"" nie jest zarejestrowana i nie ma odpowiedniego rodzaju karty rabatowej.';es_ES = 'Tarjeta con el ""%1"" código magnético no se ha registrado, y no hay un tipo de tarjeta de descuentos conveniente.';es_CO = 'Tarjeta con el ""%1"" código magnético no se ha registrado, y no hay un tipo de tarjeta de descuentos conveniente.';tr = '""%1"" manyetik kodlu kart kayıtlı değildir ve uygun bir indirim kartı türü yoktur.';it = 'La carta con codice magnetico ""%1"" non è registrata e non ci sono tipologie di carte sconto accettabili.';de = 'Karte mit dem ""%1"" Magnetcode ist nicht registriert und es gibt keine passende Rabattkartenart.'");
		EndIf;
		
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(MessageText, CardCode),
			,
			"CardCode");
		
		Return;
		
	EndIf;
	
	If FoundDiscountCards.Count() > 1 OR Not ThereAreFoundCards Then
		GoToPage(Items.Pages.ChildItems.GroupChoiceDiscountCard);
		If ThereAreFoundCards Then		
			Text = NStr("en = 'Several discount cards with code ""%1"" are detected.
			            |Select suitable card.'; 
			            |ru = 'Обнаружено несколько дисконтных карт с кодом ""%1"".
			            |Выберите подходящую карту.';
			            |pl = 'Wykryto kilka kart rabatowych z kodem ""%1"".
			            |Wybierz odpowiednią kartę.';
			            |es_ES = 'Varias tarjetas de descuentos con el código ""%1"" se han detectado.
			            |Seleccionar una tarjeta conveniente.';
			            |es_CO = 'Varias tarjetas de descuentos con el código ""%1"" se han detectado.
			            |Seleccionar una tarjeta conveniente.';
			            |tr = 'Birden fazla ""%1"" kodlu indirim kartı tespit edildi. 
			            |Uygun kartı seçin.';
			            |it = 'Sono rilevate diverse carte sconto con il codice ""%1"".
			            |Selezionare carta corretta.';
			            |de = 'Mehrere Rabattkarten mit Code ""%1"" werden erkannt.
			            |Wählen Sie die geeignete Karte aus.'");
			LabelChoiceDiscountCard = StringFunctionsClientServer.SubstituteParametersToString(Text, CardCode);
		Else // Only the kinds of cards for new card registration.
			If CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
				Text = NStr("en = 'Card with barcode ""%1"" is not registered.
				            |Select a suitable kind of card for registration of new discount card.'; 
				            |ru = 'Карта со штрихкодом ""%1"" не зарегистрирована.
				            |Выберите подходящий вид карты для регистрации новой дисконтной карты.';
				            |pl = 'Karta z kodem kreskowym ""%1"" nie jest zarejestrowana.
				            |Wybierz odpowiedni rodzaj karty do rejestracji nowej karty rabatowej.';
				            |es_ES = 'Tarjeta con el código de barras ""%1"" no se ha registrado.
				            |Seleccionar un tipo de tarjeta conveniente para registrar un nueva tarjeta de descuentos.';
				            |es_CO = 'Tarjeta con el código de barras ""%1"" no se ha registrado.
				            |Seleccionar un tipo de tarjeta conveniente para registrar un nueva tarjeta de descuentos.';
				            |tr = '""%1"" barkodlu kart kayıtlı değil.
				            |Yeni indirim kartın kaydı için uygun bir kart türü seçin.';
				            |it = 'La carta con codice a barre ""%1"" non è registrata.
				            |Selezionare un tipo adeguato di carta per la registrazione di una nuova carta sconto.';
				            |de = 'Karte mit Barcode ""%1"" ist nicht registriert.
				            |Wählen Sie eine geeignete Kartenart für die Registrierung der neuen Rabattkarte.'");
			Else
				Text = NStr("en = 'Card with magnetic code ""%1"" is not registered.
				            |Select a suitable kind of card for registration of new discount card.'; 
				            |ru = 'Карта с магнитным кодом ""%1"" не зарегистрирована.
				            |Выберите подходящий вид карты для регистрации новой дисконтной карты.';
				            |pl = 'Karta z kodem magnetycznym ""%1"" nie jest zarejestrowana.
				            |Wybierz odpowiedni rodzaj karty do rejestracji nowej karty rabatowej.';
				            |es_ES = 'Tarjeta con el código magnético ""%1"" no se ha registrado.
				            |Seleccionar un tipo de tarjeta conveniente para registrar una nueva tarjeta de descuentos.';
				            |es_CO = 'Tarjeta con el código magnético ""%1"" no se ha registrado.
				            |Seleccionar un tipo de tarjeta conveniente para registrar una nueva tarjeta de descuentos.';
				            |tr = '""%1"" manyetik kodlu kart kayıtlı değil.
				            |Yeni indirim kartın kaydı için uygun bir kart türü seçin.';
				            |it = 'La carta con codice magnetico ""%1"" non è registrata.
				            |Salezionare un tipo adeguato di carta per la registrazione di una nuova carta sconto.';
				            |de = 'Karte mit Magnetcode ""%1"" ist nicht registriert.
				            |Wählen Sie eine geeignete Kartenart für die Registrierung der neuen Rabattkarte.'");			   
			EndIf;				   
			LabelChoiceDiscountCard = StringFunctionsClientServer.SubstituteParametersToString(Text, CardCode);
		EndIf;
	ElsIf FoundDiscountCards.Count() = 1 AND ThereAreFoundCards Then
		ProcessDiscountCardChoice(FoundDiscountCards[0]);
	EndIf;
	
EndProcedure

// Procedure gets called when the user selects a particular discount card.
//
&AtClient
Procedure ProcessDiscountCardChoice(CurrentData)
	
	CloseParameters = New Structure("DiscountCard, DiscountCardRead", CurrentData.Ref, True);
	Close(CloseParameters);
	
EndProcedure

// Function checks magnetic code against template and sets magnetic code of catalog item or displays list of DK or DK kinds.
//
&AtClient
Procedure HandleReceivedCodeOnClientInWaitProcessor()
	
	HandleReceivedCodeOnClient(ReaderData, PredefinedValue("Enum.CardCodesTypes.MagneticCode"), True);
	
EndProcedure

// Procedure clicks Next in wait handler after changing card code or choice of discount card (discount card kind).
//
&AtClient
Procedure NextWaitHandler()
	
	Next(Commands["Next"]);
	
EndProcedure

#EndRegion

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// Procedure configures items visible depending on attributes of discount card kind.
//
&AtServer
Procedure ItemsVisibleSetupByCardKindOnServer()
	
	If Not Object.Owner.IsEmpty() Then
		Membership = GetDiscountCardKindAttribute(Object.Owner, "ThisIsMembershipCard");
		CardType = GetDiscountCardKindAttribute(Object.Owner, "CardType");
	Else
		Membership = False;
		CardType = PredefinedValue("Enum.CardsTypes.EmptyRef");		
	EndIf;
	
	Items.CardOwner.AutoMarkIncomplete = Membership;
	
	Items.CardOwner.Visible = Membership;
	Items.ThisIsMembershipCard.Visible = Membership;
	
	Items.CardCodeMagnetic.Visible = (CardType = PredefinedValue("Enum.CardsTypes.Magnetic")
	                                        Or CardType = PredefinedValue("Enum.CardsTypes.Mixed"));
	Items.CardCodeBarcode.Visible = (CardType = PredefinedValue("Enum.CardsTypes.Barcode")
	                                        Or CardType = PredefinedValue("Enum.CardsTypes.Mixed"));
											
	If CardType = PredefinedValue("Enum.CardsTypes.Mixed") Then
		If CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode") Then
			Items.CopyMCInBC.Visible = False;
			Items.CopyBCInMC.Visible = True;
		Else
			Items.CopyMCInBC.Visible = True;
			Items.CopyBCInMC.Visible = False;
		EndIf;
	Else
		Items.CopyMCInBC.Visible = False;
		Items.CopyBCInMC.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

 

