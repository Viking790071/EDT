#Region Variables

&AtClient
Var ReaderData; // Data cache of magnetic card reader

#EndRegion

#Region CommonProceduresAndFunctions

#Region DuplicatesControl

// Function checks whether discount cards with the same code (bar or magnetic) as in transmitted data exist in the IB
//
// Parameters:
//  Data - Structure - data on discount card for which the existence of duplicates is checked
//
&AtServerNoContext
Function GetDuplicatesNumberServer(Data)
	
	Return Catalogs.DiscountCards.CheckCatalogDuplicatesDiscountCardsByCodes(Data).Count();
	
EndFunction

// Procedure gets called after closing the form Catalog.DiscountCards.Form.DuplicatesChoiceForm.
//
&AtClient
Procedure HandleDuplicatesListFormClosure(ClosingResult, AdditionalParameters) Export
	CheckDiscountCardsDuplicates(ThisObject);
EndProcedure

// Procedure of auxiliary form opening to compare duplicated counterparties.
// 
&AtClient
Procedure HandleDuplicateChoiceSituation(Item)
		
	TransferParameters = New Structure;
	
	TransferParameters.Insert("CardCodeBarcode", TrimAll(Object.CardCodeBarcode));
	TransferParameters.Insert("CardCodeMagnetic", TrimAll(Object.CardCodeMagnetic));
	TransferParameters.Insert("Owner", Object.Owner);
	TransferParameters.Insert("Ref", Object.Ref);
	TransferParameters.Insert("CloseOnOwnerClose", True);
	
	WhatToExecuteAfterClosure = New NotifyDescription("HandleDuplicatesListFormClosure", ThisForm);
	
	OpenForm("Catalog.DiscountCards.Form.DuplicatesChoiceForm", 
				  TransferParameters, 
				  Item,
				  ,
				  ,
				  ,
				  WhatToExecuteAfterClosure,
				  FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure manages explanatory texts about existence of discount card duplicates.
// 
&AtClientAtServerNoContext
Procedure CheckDiscountCardsDuplicates(Form)
	
	Object = Form.Object;
	Items = Form.Items;
	DuplicateItemsNumber = 0;
	
	Data = New Structure("Ref, Owner, CardCodeBarcode, CardCodeMagnetic", 
	                         Object.Ref, Object.Owner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
							 
	DuplicateItemsNumber = GetDuplicatesNumberServer(Data);
	
	If DuplicateItemsNumber > 0 Then
		
		Items.ShowDoubles.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Duplicates found: %1'; ru = 'Найдены дубликаты: %1';pl = 'Znaleziono duplikaty: %1';es_ES = 'Duplicados encontrados: %1';es_CO = 'Duplicados encontrados: %1';tr = 'Kopyalar bulundu: %1';it = 'Trovati duplicati: %1';de = 'Duplikate gefunden: %1'"),
		DuplicateItemsNumber);
		Form.StructureForCheckCodes.ThereAreDuplicates = True;
		
	Else
		
		Form.StructureForCheckCodes.ThereAreDuplicates = False;
		Items.GroupDoubles.Visible=False;

	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// Procedure controls the visible of form items depending on the existence of duplicates.
//
&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	Object = Form.Object;
	CheckStructure = Form.StructureForCheckCodes;
	
	If CheckStructure.ThereAreDuplicates Then
		If Not Items.GroupDoubles.Visible Then
			Items.GroupDoubles.Visible = True;
		EndIf;
	ElsIf Items.GroupDoubles.Visible Then
		Items.GroupDoubles.Visible = False;
	EndIf;
	
EndProcedure

// The procedure controls the visible of form items depending on card kind.
//
&AtServer
Procedure ItemsVisibleByCardKindSetup()
	
	If Not Object.Owner.IsEmpty() Then
		Membership = Object.Owner.ThisIsMembershipCard;
		CardType = Object.Owner.CardType;
	Else
		Membership = False;
		CardType = Enums.CardsTypes.EmptyRef();
	EndIf;
	
	Items.CardOwner.AutoMarkIncomplete = Membership;
	
	Items.CardOwner.Visible = Membership;
	Items.ThisIsMembershipCard.Visible = Membership;
	
	Items.CardCodeMagnetic.Visible = (CardType = Enums.CardsTypes.Magnetic
	                                        Or CardType = Enums.CardsTypes.Mixed);
	Items.CardCode.Visible = (CardType = Enums.CardsTypes.Barcode
	                                        Or CardType = Enums.CardsTypes.Mixed);
											
	If CardType = Enums.CardsTypes.Mixed Then
		Items.CopyMCInBC.Visible = True;
		Items.CopyBCInMC.Visible = True;
	Else
		Items.CopyMCInBC.Visible = False;
		Items.CopyBCInMC.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

// Function returns a reference to a discount card if in the IB only a discount card not marked for deletion is registered
//
&AtServer
Function GetDiscountCardDefaultKind()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	DiscountCardTypes.Ref
		|FROM
		|	Catalog.DiscountCardTypes AS DiscountCardTypes
		|WHERE
		|	NOT DiscountCardTypes.DeletionMark";
	
	QueryResult = Query.Execute();
	
	QTDiscountCardTypes = QueryResult.Unload();
	
	If QTDiscountCardTypes.Count() = 1 Then
		Return QTDiscountCardTypes[0].Ref;
	Else
		Return Catalogs.DiscountCardTypes.EmptyRef();
	EndIf;
	
EndFunction

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
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

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	NotifyWritingNew(Object.Ref);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationSimpCurrency = DriveReUse.GetFunctionalCurrency();
	
	If Object.Ref.IsEmpty() Then
		InformationSalesAmountOnDiscountCard = 0;
		InformationDiscountPercentOnDiscountCard = 0;
		
		// If there is only one kind of discount card in the base, fill it automatically.
		If Object.Owner.IsEmpty() Then
			Object.Owner = GetDiscountCardDefaultKind();
		EndIf;
	EndIf;
	
	FillInInformationOnDiscountCard();
	
	ItemsVisibleByCardKindSetup();
	
	StructureForCheckCodes = New Structure;
	
	StructureForCheckCodes.Insert("ThereAreDuplicates", False);
	
	CheckDiscountCardsDuplicates(ThisObject);
	
	FormManagement(ThisForm);
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	// End Peripherals
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

// IN the procedure you should fill information about % of the discount and sales amount for a discount card.
//
&AtServer
Procedure FillInInformationOnDiscountCard()

	AdditionalParameters = New Structure("GetSalesAmount, Amount, PeriodPresentation", True, 0, "");
	DiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(CurrentSessionDate(), Object, AdditionalParameters);
	InformationSalesAmountOnDiscountCard = AdditionalParameters.Amount;
	InformationDiscountPercentOnDiscountCard = DiscountPercentByDiscountCard;
	If ValueIsFilled(AdditionalParameters.PeriodPresentation) Then
		Items.SalesAmountOnDiscountCard.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Sales amount (%1)'; ru = 'Сумма продаж (%1)';pl = 'Kwota sprzedaży (%1)';es_ES = 'Seleccionar el importe (%1)';es_CO = 'Seleccionar el importe (%1)';tr = 'Satış tutarı (%1)';it = 'Importo vendita (%1)';de = 'Verkaufsbetrag (%1)'"), AdditionalParameters.PeriodPresentation);
	Else
		Items.SalesAmountOnDiscountCard.Title = NStr("en = 'Sales amount'; ru = 'Сумма продаж';pl = 'Wartość sprzedaży';es_ES = 'Importe de ventas';es_CO = 'Importe de ventas';tr = 'Satış tutarı';it = 'Importo delle vendite';de = 'Verkaufsbetrag'");
	EndIf;

EndProcedure

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Object.Owner.IsEmpty() Then
		DriveClient.ShowMessageAboutError(ThisObject, "Before reading a discount card, select kind", , , "Object.Owner");
		Return;
	EndIf;
	
	// Peripherals
	If Source = "Peripherals" AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			CodeType = PredefinedValue("Enum.CardCodesTypes.Barcode");
			HandleBarcodes(DiscountCardsClient.ConvertDataFromScannerIntoArray(Parameter));
			CurrentItem = Items.CardCode;
		ElsIf EventName ="TracksData" Then
			// Processing the situation when magnetic card reader simulates clicking the Enter button after reading the magnetic card.
			CurDate = CommonClient.SessionDate();
			
			CodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode");
			HandleMagneticCardsReaderData(Parameter);
			CurrentItem = Items.CardCodeMagnetic;
			
			// Processing the situation when magnetic card reader simulates clicking the Enter button after reading the magnetic card.
			// You can cut the newline character in the peripherals settings to read magnetic cards.
			While (CommonClient.SessionDate() - CurDate) < 1 Do EndDo;			
		EndIf;
		
		Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
		CheckDiscountCardsDuplicates(ThisObject);
		FormManagement(ThisObject);
	EndIf;
	// End Peripherals
	
EndProcedure

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange of item DiscountCardKind.
//
&AtClient
Procedure KindDiscountCardOnChange(Item)
	
	ItemsVisibleByCardKindSetup();
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	CheckDiscountCardsDuplicates(ThisObject);
	FormManagement(ThisObject);
	FillInInformationOnDiscountCard();
	
EndProcedure

// Procedure - event handler OnChange of item CardOwner.
//
&AtClient
Procedure CardOwnerOnChange(Item)
	
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
EndProcedure

// Procedure - event handler OnChange of item CardCode (barcode).
//
&AtClient
Procedure CardCodeOnChange(Item)
	
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
	CheckDiscountCardsDuplicates(ThisObject);
	FormManagement(ThisObject);
	
EndProcedure

// Procedure - event handler Click item ShowDuplicates.
//
&AtClient
Procedure ShowDuplicatesClick(Item)
	HandleDuplicateChoiceSituation(Item);
EndProcedure

// Procedure - event handler OnChange of item CardCodeMagnetic.
//
&AtClient
Procedure CardCodeMagneticOnChange(Item)
	
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	
	CheckDiscountCardsDuplicates(ThisObject);
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region BarcodesAndShopEquipment

// Procedure processes barcode data transmitted from form notifications data processor.
//
&AtClient
Procedure HandleBarcodes(BarcodesData)
	
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
	
	ReaderData = Data;
	HandleReceivedCodeOnClient(ReaderData, PredefinedValue("Enum.CardCodesTypes.MagneticCode"), True);
	
EndProcedure

// Function checks the magnetic code against the template and returns a list of DK, magnetic code or barcode.
//
&AtServer
Function HandleReceivedCodeOnServer(Data, CardCodeType, Preprocessing, ThereAreFoundCards = False, ThereIsTemplate = False)
	
	ThereAreFoundCards = False;
	
	If Not Object.Owner.IsEmpty() AND Not Object.Owner.DiscountCardTemplate.IsEmpty() Then
		ThereIsTemplate = True;
	Else
		ThereIsTemplate = False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	CodeType = CardCodeType;
	If CodeType = Enums.CardCodesTypes.MagneticCode Then
		// When function is called, the parameter "Preprocessing" shall be set to value False in order not to use magnetic card templates.
		// Line received by lines concatenation from all magnetic tracks will be used as a card code.
		// Majority of discount cards has only one track on which only card number is recorded in the format ";CardCode?".
		If Preprocessing Then
			CurCardCode = Data[0]; // Data of 3 magnetic card tracks. At this moment it is not used. Can be used if the card is not found.
			                        // When a card does not correspond to any template, the warning will appear but the button
			                        // "Ready" in the form will not be pressed.
			DiscountCards = DiscountCardsServerCall.FindDiscountCardTypesByDataFromMagneticCardReader(Data, CodeType, Object.Owner);
			
			Return DiscountCards;
		Else
			If TypeOf(Data) = Type("Array") Then
				CurCardCode = Data[0];
			Else
				CurCardCode = Data;
			EndIf;
			DiscountCardsServerCall.PrepareCardCodeByDefaultSettings(CurCardCode);
			
			Return CurCardCode;
		EndIf;
	Else
		Return Data;
	EndIf;
		
EndFunction

// Function checks the magnetic code against the template and sets magnetic code or catalog item barcode.
//
&AtClient
Procedure HandleReceivedCodeOnClient(Data, ReceivedCodeType, Preprocessing)
	
	Var ThereAreFoundCards, ThereIsTemplate;
	
	Result = HandleReceivedCodeOnServer(Data, ReceivedCodeType, Preprocessing, ThereAreFoundCards, ThereIsTemplate);
	If ReceivedCodeType = PredefinedValue("Enum.CardCodesTypes.MagneticCode") Then
		If TypeOf(Result) = Type("String") Then
			Object.CardCodeMagnetic = Result;
		Else
			If Result.Count() = 1 Then
				Object.CardCodeMagnetic = Result.Get(0).Value;
			ElsIf Result.Count() = 0 Then
				If ThereIsTemplate Then
					DriveClient.ShowMessageAboutError(Object, "Card code does not correspond to selected kind of discount cards.");
				Else
					DriveClient.ShowMessageAboutError(Object, "Card code does not correspond to any template of magnetic cards.");
				EndIf;
			Else
				ValueSelected = Result.ChooseItem(NStr("en = 'Select magnetic stripe card code'; ru = 'Выбор кода магнитной карты';pl = 'Wybierz kod karty magnetycznej';es_ES = 'Seleccionar el código de la tarjeta de banda magnética';es_CO = 'Seleccionar el código de la tarjeta de banda magnética';tr = 'Manyetik şeritli kartın kodunu seçin';it = 'Selezionare codice carta magnetica';de = 'Wählen Sie Magnetstreifenkartencode'"));
				If ValueSelected <> Undefined Then
					Object.MagneticCode = ValueSelected.Value;
				EndIf;
			EndIf;
		EndIf;
	Else
		Object.CardCodeBarcode = Result;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - command handler CopyBCInMC of the form.
//
&AtClient
Procedure CopyBCInMC(Command)
	
	Object.CardCodeMagnetic = Object.CardCodeBarcode;
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	CheckDiscountCardsDuplicates(ThisObject);
	
EndProcedure

// Procedure - command handler CopyMCInBC of the form.
//
&AtClient
Procedure CopyMCInBC(Command)
	
	Object.CardCodeBarcode = Object.CardCodeMagnetic;
	Object.Description = DiscountCardsServerCall.SetDiscountCardName(Object.Owner, Object.CardOwner, Object.CardCodeBarcode, Object.CardCodeMagnetic);
	CheckDiscountCardsDuplicates(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

