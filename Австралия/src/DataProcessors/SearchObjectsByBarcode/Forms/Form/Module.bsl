
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UsePeripherals = DriveReUse.UsePeripherals();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals" AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			Barcode = "";
			If Parameter[1] = Undefined Then
				Barcode = Parameter[0]; // Get a barcode from the basic data
			Else
				Barcode = Parameter[1][1]; // Get a barcode from the additional data
			EndIf;
			ShowChangeDocument();
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

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BarcodeOnChange(Item)
	
	ShowChangeDocument();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ShowChangeDocument()
	
	If Not IsBlankString(Barcode) Then
		
		Status(NStr("en = 'Searching for document by barcode...'; ru = 'Поиск документа по штрихкоду...';pl = 'Wyszukiwanie dokumentu według kodu kreskowego...';es_ES = 'Buscando el documento por el código de barras...';es_CO = 'Buscando el documento por el código de barras...';tr = 'Belge barkodla aranıyor...';it = 'Ricerca documenti per codice a barre...';de = 'Suche nach Dokumenten über den Barcode...'"));
		ReferenceByCode = ReferenceByCodeAtServer(Barcode);
		
		If ValueIsFilled(ReferenceByCode) Then
			
			ActionsAfterMakingScanningEvent = ActionsAfterMakingScanningEvent(ReferenceByCode, UsersClientServer.CurrentUser());
			
			If ActionsAfterMakingScanningEvent.Open Then
				ShowValue(, ReferenceByCode);
			Else
				ShowUserNotification(ActionsAfterMakingScanningEvent.NotificationText,
					GetURL(ReferenceByCode),
					,
					PictureLib.Document,
					UserNotificationStatus.Important);
				NotifyChanged(ReferenceByCode);
			EndIf;
			
		EndIf;
		
		Barcode = "";
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ActionsAfterMakingScanningEvent(Document, User)
	
	Return BarcodesInPrintForms.ActionsAfterMakingScanningEvent(Document, User);
	
EndFunction

&AtServerNoContext
Function ReferenceByCodeAtServer(Barcode)
	
	Return BarcodesInPrintForms.ReferenceByCode(Barcode);
	
EndFunction

#EndRegion