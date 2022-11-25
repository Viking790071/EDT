#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnCreateAtServer(ThisObject, Object, "ContactInformationGroup", FormItemTitleLocation.Left);
	// End StandardSubsystems.ContactInformation

	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.ContactInformation
	ContactsManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ContactInformation
	ContactsManager.AfterWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.ContactInformation
	ContactsManager.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If NOT CheckByIsDefault() Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Default shipping address for %1 already exists.'; ru = 'Для %1 уже задан адрес доставки по умолчанию.';pl = 'Domyślny adres wysyłki %1 już istnieje.';es_ES = 'Dirección de envío por defecto para %1 ya existe.';es_CO = 'Dirección de envío por defecto para %1 ya existe.';tr = '%1 için varsayılan teslimat adresi zaten mevcut.';it = 'L''indirizzo di consegna predefinito per %1 già esiste.';de = 'Standardversandadresse für %1 existiert bereits.'"),
			Object.Owner);
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
	EndIf;
	
	If ValueIsFilled(Object.DeliveryTimeFrom) AND ValueIsFilled(Object.DeliveryTimeTo)
		AND Object.DeliveryTimeFrom > Object.DeliveryTimeTo Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Delivery start time should be less than end time'; ru = 'Дата начала доставки должна быть раньше даты окончания доставки.';pl = 'Czas rozpoczęcia dostawy powinien być krótszy niż czas zakończenia dostawy';es_ES = 'La hora del inicio de la entrega debe ser menor de la hora final';es_CO = 'La hora del inicio de la entrega debe ser menor de la hora final';tr = 'Teslimat başlangıç zamanı bitiş zamanından önce olmalıdır';it = 'L''orario di inizio consegna dovrebbe essere inferiore all''orario di fine';de = 'Die Lieferstartzeit soll vor der Endzeit liegen'"),,,,Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtServer
Function CheckByIsDefault()
	
	If NOT Object.IsDefault Then
		Return True;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	TRUE AS Field1
	|FROM
	|	Catalog.ShippingAddresses AS ShippingAddresses
	|WHERE
	|	ShippingAddresses.Owner = &Owner
	|	AND ShippingAddresses.Ref <> &Ref
	|	AND ShippingAddresses.IsDefault";
	
	Query.SetParameter("Owner", Object.Owner);
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().IsEmpty();
	
EndFunction

#Region LibraryHandlers

// StandardSubsystems.ContactInformation

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	ContactsManagerClient.OnChange(ThisObject, Item);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	ContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnClick(Item, StandardProcessing)
	ContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	ContactsManagerClient.Clearing(ThisObject, Item.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	ContactsManagerClient.ExecuteCommand(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	ContactsManagerClient.AutoComplete(Text, ChoiceData, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationChoiceProcessing(Item, SelectedValue, StandardProcessing)
	ContactsManagerClient.ChoiceProcessing(ThisObject, SelectedValue, Item.Name, StandardProcessing);
EndProcedure

&AtServer
Procedure Attachable_UpdateContactInformation(Result) Export
	ContactsManager.UpdateContactInformation(ThisObject, Object, Result);
EndProcedure

// End StandardSubsystems.ContactInformation

#EndRegion

#EndRegion
