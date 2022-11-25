#Region Public

// Handler of the OnChange event of a contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     Item - FormField - a form item containing contacts presentation.
//     IsTabularSection - Boolean - a flag specifying that the item is contained in a form table.
//
Procedure OnChange(Form, Item, IsTabularSection = False) Export
	
	OnContactsChange(Form, Item, IsTabularSection, True);
	
EndProcedure

// Handler of the StartChoice event of a contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     Item - FormField - a form item containing contacts presentation.
//     Modified - Boolean - a lag specifying that the form was modified.
//     StandardProcessing - Boolean - a flag specifying that standard processing is required for the form event.
//     OpeningParameters - Structure - form opening parameters of contacts input.
//
Procedure StartChoice(Form, Item, Modified = True, StandardProcessing = False, OpeningParameters = Undefined) Export
	StandardProcessing = False;
	
	Result = New Structure;
	Result.Insert("AttributeName", Item.Name);
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	RowData = GetAdditionalValueString(Form, Item, IsTabularSection);
	
	// Setting presentation equal to the attribute if the presentation was modified directly in the form field and no longer matches the attribute.
	UpdateConextMenu = False;
	If Item.Type = FormFieldType.InputField Then
		If FillingData[Item.Name] <> Item.EditText Then
			FillingData[Item.Name] = Item.EditText;
			OnContactsChange(Form, Item, IsTabularSection, False);
			UpdateConextMenu  = True;
			Form.Modified = True;
		EndIf;
		EditText = Item.EditText;
	Else
		If RowData <> Undefined AND ValueIsFilled(RowData.Value) Then
			EditText = Form[Item.Name];
		Else
			EditText = "";
		EndIf;
	EndIf;
	
	ContactInformationParameters = Form.ContactInformationParameters[RowData.ItemForPlacementName];
	
	FormOpenParameters = New Structure;
	FormOpenParameters.Insert("ContactInformationKind", RowData.Kind);
	FormOpenParameters.Insert("Value",                RowData.Value);
	FormOpenParameters.Insert("Presentation",           EditText);
	FormOpenParameters.Insert("ReadOnly",          Form.ReadOnly Or Item.ReadOnly);
	FormOpenParameters.Insert("PremiseType",            ContactInformationParameters.AddressParameters.PremiseType);
	FormOpenParameters.Insert("Country",                  ContactInformationParameters.AddressParameters.Country);
	FormOpenParameters.Insert("IndexOf",                  ContactInformationParameters.AddressParameters.IndexOf);
	FormOpenParameters.Insert("ContactInformationAdditionalAttributeDetails", Form.ContactInformationAdditionalAttributeDetails);
	
	If Not IsTabularSection Then
		FormOpenParameters.Insert("Comment", RowData.Comment);
	EndIf;
	
	If ValueIsFilled(OpeningParameters) AND TypeOf(OpeningParameters) = Type("Structure") Then
		For each ValueAndKey In OpeningParameters Do
			FormOpenParameters.Insert(ValueAndKey.Key, ValueAndKey.Value);
		EndDo;
	EndIf;
	
	Notification = New NotifyDescription("PresentationStartChoiceCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("FillingData",        FillingData);
	Notification.AdditionalParameters.Insert("IsTabularSection",       IsTabularSection);
	Notification.AdditionalParameters.Insert("PlacementItemName",   RowData.ItemForPlacementName);
	Notification.AdditionalParameters.Insert("RowData",            RowData);
	Notification.AdditionalParameters.Insert("Item",                 Item);
	Notification.AdditionalParameters.Insert("Result",               Result);
	Notification.AdditionalParameters.Insert("Form",                   Form);
	Notification.AdditionalParameters.Insert("UpdateConextMenu", UpdateConextMenu);
	
	OpenContactInformationForm(FormOpenParameters,, Notification);
	
EndProcedure

// Handler of the Clearing event for a contact information form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     AttrivuteName - String - a name of form attribute related to contacts presentation.
//
Procedure Clearing(Val Form, Val AttributeName) Export
	
	Result = New Structure("AttributeName", AttributeName);
	FoundRow = Form.ContactInformationAdditionalAttributeDetails.FindRows(Result)[0];
	FoundRow.Value      = "";
	FoundRow.Presentation = "";
	FoundRow.Comment   = "";
	
	Form[AttributeName] = "";
	Form.Modified = True;
		
	If FoundRow.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Result.Insert("UpdateConextMenu", True);
		Result.Insert("ItemForPlacementName", FoundRow.ItemForPlacementName);
	EndIf;
	
	UpdateFormContactInformation(Form, Result);
EndProcedure

// Handler of the command related to contacts (write an email, open an address, and so on).
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     CommandName - String - a name of the automatically generated action command.
//
Procedure ExecuteCommand(Val Form, Val CommandName) Export
	
	If StrStartsWith(CommandName, "ContactInformationAddInputField") Then
		
		ItemForPlacementName = Mid(CommandName, StrLen("ContactInformationAddInputField") + 1);
		Notification = New NotifyDescription("ContactInformationAddInputFieldCompletion", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("Form", Form);
		Notification.AdditionalParameters.Insert("ItemForPlacementName", ItemForPlacementName);
		Notification.AdditionalParameters.Insert("CommandName", CommandName);
		Form.ShowChooseFromMenu(Notification, Form.ContactInformationParameters[ItemForPlacementName].ItemsToAddList, Form.Items[CommandName]);
		Return;
		
	ElsIf StrStartsWith(CommandName, "Command") Then
		
		AttributeName = StrReplace(CommandName, "Command", "");
		ContextMenuCommand = Undefined;
		
	ElsIf StrStartsWith(CommandName, "MenuSubmenuAddress") Then
		
		AttributeName         = StrReplace(CommandName, "MenuSubmenuAddress", "");
		Position              = StrFind(AttributeName, "_ContactInformationField");
		SourceAttributeName = Left(AttributeName, Position -1);
		AttributeName         = Mid(AttributeName, Position + 1);
		ContextMenuCommand = Undefined;
		
	ElsIf StrStartsWith(CommandName, "YandexMapMenu") 
		OR StrStartsWith(CommandName, "GoogleMapMenu") Then
		
		ContextMenuCommand = ContextMenuCommand(CommandName);
		AttributeName = Mid(ContextMenuCommand.AttributeName, 5);
		
	Else
		
		ContextMenuCommand = ContextMenuCommand(CommandName);
		AttributeName = ContextMenuCommand.AttributeName;
		
	EndIf;
	
	Result = New Structure("AttributeName", AttributeName);
	FoundRows = Form.ContactInformationAdditionalAttributeDetails.FindRows(Result);
	If FoundRows.Count() = 0 Then
		Return;
	EndIf;
	
	FoundRow          = FoundRows[0];
	ContactInformationType  = FoundRow.Type;
	ItemForPlacementName = FoundRow.ItemForPlacementName;
	Result.Insert("ItemForPlacementName", ItemForPlacementName);
	
	If ContextMenuCommand <> Undefined Then
		If ContextMenuCommand.Command = "Comment" Then
			EnterComment(Form, ContextMenuCommand.AttributeName, FoundRow, Result);
		ElsIf ContextMenuCommand.Command = "History" Then
			OpenHistoryChangeForm(Form, FoundRow);
		ElsIf ContextMenuCommand.Command = "YandexMap" Then
			ShowAddressOnMap(FoundRow.Presentation, "Yandex.Maps");
		ElsIf ContextMenuCommand.Command = "GoogleMap" Then
			ShowAddressOnMap(FoundRow.Presentation, "GoogleMaps");
		Else
			FirstItem = FoundRow.AttributeName;
			Index = Form.ContactInformationAdditionalAttributeDetails.IndexOf(FoundRow);
			If ContextMenuCommand.MovementDirection = 1 Then
				If Index < Form.ContactInformationAdditionalAttributeDetails.Count() - 1 Then
					SecondItem = Form.ContactInformationAdditionalAttributeDetails.Get(Index + 1).AttributeName;
				EndIf;
			Else
				If Index > 0 Then
					SecondItem = Form.ContactInformationAdditionalAttributeDetails.Get(Index - 1).AttributeName;
				EndIf;
			EndIf;
			Result = New Structure("ReorderItems, FirstItem, SecondItem", True, FirstItem, SecondItem);
			Form.CurrentItem = Form.Items[SecondItem];
			UpdateFormContactInformation(Form, Result);
		EndIf;
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		
		Result = New Structure("AttributeName", SourceAttributeName);
		CustomerRow = Form.ContactInformationAdditionalAttributeDetails.FindRows(Result)[0];
		
		Comment = CustomerRow.Comment; // Save the old comment.
		If CustomerRow.Property("InternationalAddressFormat") AND CustomerRow.InternationalAddressFormat Then
			
			FillPropertyValues(CustomerRow, FoundRow, "Comment");
			AddressPresentation = StringFunctionsClientServer.LatinString(FoundRow.Presentation);
			CustomerRow.Presentation        = AddressPresentation;
			Form[CustomerRow.AttributeName]  = AddressPresentation;
			CustomerRow.Value             = ContactInformationManagementInternalServerCall.ContactsByPresentation(AddressPresentation, ContactInformationType);
			
		Else
			
			FillPropertyValues(CustomerRow, FoundRow, "Value, Presentation,Comment");
			Form[CustomerRow.AttributeName] = FoundRow.Presentation;
			
		EndIf;
		
		Form.Modified = True;
		Result = New Structure();
		Result.Insert("UpdateConextMenu",  True);
		Result.Insert("AttributeName",             CustomerRow.AttributeName);
		Result.Insert("Comment",              Comment);
		Result.Insert("ItemForPlacementName", FoundRow.ItemForPlacementName);
		UpdateFormContactInformation(Form, Result);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		MailAddr = Form.Items[AttributeName].EditText;
		ContactInformationSource = Form.ContactInformationParameters[ItemForPlacementName].Owner;
		CreateEmail("", MailAddr, ContactInformationType, ContactInformationSource);
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		CanSendSMSMessage = Form.ContactInformationParameters[ItemForPlacementName].CanSendSMSMessage;
		
		Parameters = New Structure("PhoneNumber, ContactInformationType, ContactInformationSource");
		Parameters.PhoneNumber = Form.Items[AttributeName].EditText;
		Parameters.ContactInformationType = ContactInformationType;
		Parameters.ContactInformationSource = Form.ContactInformationParameters[ItemForPlacementName].Owner;
		
		If IsBlankString(Parameters.PhoneNumber) Then
			If CanSendSMSMessage Then
				WarningText = NStr("ru = 'Для совершения звонка или отправки SMS требуется ввести номер телефона.'; en = 'To call or send an SMS, enter the phone number.'; pl = 'W celu nawiązania połączenia lub wysłania wiadomości SMS należy wprowadzić numer telefonu.';es_ES = 'Para llamar o enviar SMS se requiere introducir el número del teléfono.';es_CO = 'Para llamar o enviar SMS se requiere introducir el número del teléfono.';tr = 'Aramak veya SMS göndermek için telefon numarasını girin.';it = 'Inserire il numero di telefono per poter chiamare o inviare un SMS.';de = 'Um einen Anruf zu tätigen oder eine SMS zu versenden, müssen Sie eine Telefonnummer eingeben.'");
			Else
				WarningText = NStr("ru = 'Для совершения звонка требуется ввести номер телефона.'; en = 'To call, enter the phone number.'; pl = 'W celu nawiązania połączenia należy podać numer telefonu.';es_ES = 'Para llamar se requiere introducir el número del teléfono.';es_CO = 'Para llamar se requiere introducir el número del teléfono.';tr = 'Aramak için telefon numarasını girin.';it = 'Per chiamare, inserisci il numero di telefono.';de = 'Um einen Anruf zu tätigen, müssen Sie eine Telefonnummer eingeben.'");
			EndIf;
			ShowMessageBox(, WarningText);
		ElsIf CanSendSMSMessage Then
			List = New ValueList;
			List.Add("Call", NStr("ru = 'Позвонить'; en = 'Call'; pl = 'Zadzwoń';es_ES = 'Llamada';es_CO = 'Llamada';tr = 'Ara';it = 'Call';de = 'Anruf'"),, PictureLib.Call);
			List.Add("SendSMSMessage", NStr("ru = 'Отправить SMS...'; en = 'Send SMS ...'; pl = 'Wyślij SMS...';es_ES = 'Enviar SMS...';es_CO = 'Enviar SMS...';tr = 'SMS gönder...';it = 'Invia SMS...';de = 'SMS senden...'"),, PictureLib.SendSMSMessage);
			NotificationMenu = New NotifyDescription("AfterChoiceFromPhoneMenu", ThisObject, Parameters);
			Form.ShowChooseFromMenu(NotificationMenu, List, Form.Items[CommandName]);
		Else
			Telephone(Parameters.PhoneNumber);
		EndIf;
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Skype") Then
		Parameters = New Structure("SkypeUsername");
		Parameters.SkypeUsername = Form.Items[AttributeName].EditText;
		List = New ValueList;
		List.Add("Call", NStr("ru = 'Позвонить'; en = 'Call'; pl = 'Zadzwoń';es_ES = 'Llamada';es_CO = 'Llamada';tr = 'Ara';it = 'Call';de = 'Anruf'"));
		List.Add("StartChat", NStr("ru = 'Начать чат'; en = 'Start a chat'; pl = 'Rozpocznij czat';es_ES = 'Empezar la conversación';es_CO = 'Empezar la conversación';tr = 'Sohbeti başlat';it = 'Avvia una chat';de = 'Chat beginnen'"));
		NotificationMenu = New NotifyDescription("AfterChoiceFromSkypeMenu", ThisObject, Parameters);
		Form.ShowChooseFromMenu(NotificationMenu, List, Form.Items[CommandName]);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		HyperlinkAddress = Form.Items[AttributeName].EditText;
		GoToWebLink("", HyperlinkAddress, ContactInformationType);
	EndIf;
	
EndProcedure

// Handler of the AutoComplete event of a contacts form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Text - String - a text string entered by the user in the contacts field.
//     ChoiceData - ValueList - contains a value list that will be used for standard event 
//                                             processing.
//     StandardProcessing - Boolean - this parameter is used to indicate whether the standard 
//                                             (system) event processing is performed. If this 
//                                             parameter is set to False in the processing procedure, 
//                                             standard processing is skipped.
//
Procedure AutoComplete(Val Text, ChoiceData, StandardProcessing = False) Export
	
	If StrLen(Text) > 2 Then
		ContactInformationManagementInternalServerCall.AddressAutoComplete(Text, ChoiceData);
		If TypeOf(ChoiceData) = Type("ValueList") Then
			StandardProcessing = (ChoiceData.Count() = 0);
		EndIf;
	EndIf;
	
EndProcedure

// Handler of the CoiceProcessing event of a contacts form field.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     SelectedValue - String - a selected value that will be set as the value of the contacts input 
//                                            field.
//     AttrivuteName - String - a name of form attribute related to contacts presentation.
//     StandardProcessing - Boolean - this parameter is used to indicate whether the standard 
//                                            (system) event processing is performed. If this 
//                                            parameter is set to False in the processing procedure, 
//                                            standard processing is skipped.
//
Procedure ChoiceProcessing(Val Form, Val SelectedValue, Val AttributeName, StandardProcessing = False) Export
	
	StandardProcessing = False;
	Form[AttributeName] = SelectedValue.Presentation;
	
	Filter = New Structure("AttributeName", AttributeName);
	Form.ContactInformationAdditionalAttributeDetails.FindRows(Filter);
	FoundRows = Form.ContactInformationAdditionalAttributeDetails.FindRows(New Structure("AttributeName", AttributeName));
	If FoundRows.Count() > 0 Then
		FoundRows[0].Presentation = SelectedValue.Presentation;
		FoundRows[0].Value      = SelectedValue.Address;
	EndIf;
	
EndProcedure

// Opens the address input form for the contact information form.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     Result - Arbitrary - data provided by the command handler.
//
Procedure OpenAddressInputForm(Form, Result) Export
	
	If Result <> Undefined Then
		If Result.Property("AddressFormItem") Then
			StartChoice(Form, Form.Items[Result.AddressFormItem]);
		EndIf;
	EndIf;
	
EndProcedure

// Handler of the refresh operation for the contacts form.
// It is called from the attachable actions when deploying the Contacts subsystem.
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     Result - Arbitrary - data provided by the command handler.
//
Procedure FormRefreshControl(Form, Result) Export
	
	// Address input form callback analysis.
	OpenAddressInputForm(Form, Result);
	
EndProcedure

// Handler of the ChoiceProcessing event for world countries.
// Implements functionality for automated creation of WorldCountries catalog item based on user choice.
//
// Parameters:
//     Item - FormField - an item containing the world country to be edited.
//     SelectedValue - Arbitrary - selection value.
//     StandardProcessing - Boolean - a flag specifying that standard processing is required for the form event.
//
Procedure WorldCountryChoiceProcessing(Item, SelectedValue, StandardProcessing) Export
	If Not StandardProcessing Then 
		Return;
	EndIf;
	
	SelectedValueType = TypeOf(SelectedValue);
	If SelectedValueType = Type("Array") Then
		TransformationList = New Map;
		For Index = 0 To SelectedValue.UBound() Do
			Data = SelectedValue[Index];
			If TypeOf(Data) = Type("Structure") AND Data.Property("Code") Then
				TransformationList.Insert(Index, Data.Code);
			EndIf;
		EndDo;
		
		If TransformationList.Count() > 0 Then
			ContactInformationManagementInternalServerCall.WorldCountriesCollectionByClassifierData(TransformationList);
			For Each KeyValue In TransformationList Do
				SelectedValue[KeyValue.Key] = KeyValue.Value;
			EndDo;
		EndIf;
		
	ElsIf SelectedValueType = Type("Structure") AND SelectedValue.Property("Code") Then
		SelectedValue = ContactInformationManagementInternalServerCall.WorldCountryByClassifierData(SelectedValue.Code);
		
	EndIf;
	
EndProcedure

// Constructor used to create a structure with contact information form opening parameters.
//
// Parameters:
//  ContactsKind - CatalogRef.ContactsKinds - a kind of contacts to be edited.
//  Value - String - a serialized value of contacts fields in the XML format.
//  Presentation - String - optional. Presentation of contacts.
//  Comment - String - a contacts comment.
//  ContactInformationType - EnumRef.ContactInformationTypes - optional. Contacts type.
//                                      If specified, the fields matching the type are added to the returned structure.
// 
// Returns:
//  Structure - contains the following fields:
//  * ContactsKind - CatalogRef.ContactsKinds - a kind of information to be edited,
//  * Value - String - a serialized value of the contacts fields.
//  * Presentation - String - optional presentation.
//  * ContactInformationType - EnumRef.ContactInformationTypes - the contact information type, 
//                                                                            provided that it was specified in the parameters.
//  * Country - String - a world country only if the contacts type Address is specified.
//  * State - String - a value of the state field only if the Address contact information type is specified.
//                                       Relevant for the EEU countries.
//  * ZipCode - String - a world country only if the Address contact information type is specified.
//  * PremiseType - String - a premise type in the address input form (only if Address is specified 
//                                       as contact information type).
//  * CountryCode - String - a phone code of a world country only if the contacts type Phone is specified.
//  * CityCode - String - a phone code of a city only if the contacts type Phone is specified.
//  * PhoneNumber - String - a phone number only if the contacts type Phone is specified.
//  * Additional - String - an additional phone number only if the contacts type Phone is specified.
//
Function ContactInformationFormParameters(ContactInformationKind, Value,
	Presentation = Undefined, Comment = Undefined, ContactInformationType = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ContactInformationKind", ContactInformationKind);
	FormParameters.Insert("Value", Value);
	FormParameters.Insert("Presentation", Presentation);
	FormParameters.Insert("Comment", Comment);
	If ContactInformationType <> Undefined Then
		FormParameters.Insert("ContactInformationType", ContactInformationType);
		If ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
			FormParameters.Insert("Country");
			FormParameters.Insert("State");
			FormParameters.Insert("IndexOf");
			FormParameters.Insert("PremiseType", "Apartment");
		ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
			FormParameters.Insert("CountryCode");
			FormParameters.Insert("CityCode");
			FormParameters.Insert("PhoneNumber");
			FormParameters.Insert("Extension");
		EndIf;
	EndIf;
	
	Return FormParameters;
	
EndFunction

// Opens an appropriate contact information form for editing or viewing.
//
//  Parameters:
//      Parameters - Arbitrary - the ContactsFormParameters function.
//      Owner - Arbitrary - a form parameter.
//      Notification - NotifyDescription - used to process form closing.
//
//  Returns:
//   ClientApplicationForm - a requested form.
//
Function OpenContactInformationForm(Parameters, Owner = Undefined, Notification = Undefined) Export
	Parameters.Insert("OpenByScenario", True);
	Return OpenForm("DataProcessor.ContactInformationInput.Form", Parameters, Owner,,,, Notification);
EndFunction

// Creates a contact information email.
//
// Parameters:
//  FieldsValues - String, Structure, Map, ValueList - contacts value.
//  Presentation - String - a contact information presentation. Used if unable to determine 
//                              presentation based on a parameter. FieldsValues (the Presentation field is not available).
//  ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes,
//                         Structure - used if unable to determine type by the FieldsValues field.
//  ContactsSource - Arbitrary - an owner object of contacts.
//
Procedure CreateEmail(Val FieldsValues, Val Presentation = "", ExpectedKind = Undefined, ContactInformationSource = Undefined) Export
	
	ContactInformation = ContactInformationManagementInternalServerCall.TransformContactInformationXML(
		New Structure("FieldsValues, Presentation, ContactInformationKind", FieldsValues, Presentation, ExpectedKind));
		
	InformationType = ContactInformation.ContactInformationType;
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Нельзя создать письмо по контактной информацию с типом ""%1""'; en = 'Cannot create a contact information email with ""%1"" type'; pl = 'Nie można utworzyć wiadomości e-mail według informacji kontaktowych z typem ""%1""';es_ES = 'No se puede crear un correo electrónico por la información de contacto con el tipo ""%1""';es_CO = 'No se puede crear un correo electrónico por la información de contacto con el tipo ""%1""';tr = '""%1"" tür iletişim bilgileri ile e-posta adresini oluşturamaz';it = 'Impossibile creare una email di informazione di contatto con tipo ""%1""';de = 'Kann keine E-Mail nach Kontaktinformationen mit dem Typ ""%1"" erstellen'"), InformationType);
	EndIf;
	
	If FieldsValues = "" AND IsBlankString(Presentation) Then
		ShowMessageBox(,NStr("ru = 'Для отправки письма необходимо ввести адрес электронной почты.'; en = 'To send an email, enter the email address.'; pl = 'W celu wysłania wiadomości należy wpisać adres e-mail.';es_ES = 'Para enviar el correo es necesario introducir la dirección del correo electrónico.';es_CO = 'Para enviar el correo es necesario introducir la dirección del correo electrónico.';tr = 'E-posta göndermek için e-posta adresi girilmelidir.';it = 'Per mandare una email, inserisci indirizzo email.';de = 'Um eine E-Mail zu versenden, müssen Sie eine E-Mail-Adresse eingeben.'"));
		Return;
	EndIf;
	
	XMLData = ContactInformation.XMLData;
	MailAddr = ContactInformationManagementInternalServerCall.ContactInformationCompositionString(XMLData);
	If TypeOf(MailAddr) <> Type("String") Then
		Raise NStr("ru = 'Ошибка получения адреса электронной почты, неверный тип контактной информации'; en = 'Error getting email address. Invalid contact information type'; pl = 'Wystąpił błąd podczas odbierania adresu e-mail, nieprawidłowy typ informacji kontaktowych';es_ES = 'Ha ocurrido un error al recibir la dirección de correo electrónico, tipo de la información de contacto incorrecto';es_CO = 'Ha ocurrido un error al recibir la dirección de correo electrónico, tipo de la información de contacto incorrecto';tr = 'E-posta adresi alınırken bir hata oluştu, iletişim bilgilerin türü yanlış';it = 'Errore di ricezione indirizzo email. Tipo informazioni di contatto non valide';de = 'Beim Empfang der E-Mail-Adresse ist ein Fehler aufgetreten, falscher Kontaktinformationstyp'");
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailClient = CommonClient.CommonModule("EmailOperationsClient");
		
		Recipient = New Array;
		Recipient.Add(New Structure("Address, Presentation, ContactInformationSource", 
			MailAddr, StrReplace(String(ContactInformationSource), ",", ""), ContactInformationSource));
		SendOptions = New Structure("Recipient", Recipient);
		ModuleEmailClient.CreateNewEmailMessage(SendOptions);
	Else
		// No email subsystem, using the platform notification.
		Notification = New NotifyDescription("CreateContactInformationEmailCompletion", ThisObject, MailAddr);
		SuggestionText = NStr("ru = 'Для отправки письма необходимо установить расширение для работы с файлами.'; en = 'To send email messages, you should have the file system extension installed.'; pl = 'Aby wysłać wiadomość e-mail, zainstaluj rozszerzenie operacji na plikach.';es_ES = 'Para enviar el correo electrónico, instalar la extensión de la operación de archivos.';es_CO = 'Para enviar el correo electrónico, instalar la extensión de la operación de archivos.';tr = 'E-posta göndermek için, dosyalarla çalışmak için bir uzantı yüklemeniz gerekir.';it = 'Per poter inviare messaggi email è necessario installare l''estensione del file di sistema.';de = 'Um die E-Mail zu senden, installieren Sie die Dateioperationserweiterung.'");
		CommonClient.CheckFileSystemExtensionAttached(Notification, SuggestionText);
	EndIf;
	
EndProcedure

// Creates a contact information email.
//
// Parameters:
//  FieldsValues - String, Structure, Map, ValueList - contacts.
//  Presentation - String - presentation. Used if unable to determine presentation based on a parameter.
//                                           FieldsValues (the Presentation field is not available).
//  ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes,
//                                  Structure - used if unable to determine type by
//                                              the FieldsValues field.
//  ContactsSource - AnyRef - an object that is he contacts source.
//
Procedure CreateSMSMessage(Val FieldsValues, Val Presentation = "", ExpectedKind = Undefined, ContactInformationSource = "") Export
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.SMS") Then
		Raise NStr("ru = 'Отправка SMS недоступна.'; en = 'SMS sending is not available.'; pl = 'Wysyłanie wiadomości SMS nie jest dostępne.';es_ES = 'El envío de SMS no disponible.';es_CO = 'El envío de SMS no disponible.';tr = 'SMS gönderilemez.';it = 'L''invio SMS non è disponibile.';de = 'Das Senden von SMS ist nicht verfügbar.'");
	EndIf;
	
	ContactInformation = ContactInformationManagementInternalServerCall.TransformContactInformationXML(
		New Structure("FieldsValues, Presentation, ContactInformationKind", FieldsValues, Presentation, ExpectedKind));
		
	InformationType = ContactInformation.ContactInformationType;
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Нельзя отправитьSMS по контактной информацию с типом ""%1""'; en = 'Cannot sendSMS by contact information with type ""%1""'; pl = 'Nie można wysłać wiadomość SMS zgodnie informacji kontaktowej z rodzajem ""%1""';es_ES = 'No se puede enviar SMS por la información de contacto con el tipo ""%1""';es_CO = 'No se puede enviar SMS por la información de contacto con el tipo ""%1""';tr = '""%1"" tür iletişim bilgileri ile SMS gönderilemez';it = 'Impossibile inviare SMS per informazioni di contatto di ditpo ""%1""';de = 'Sie können keine SMS über Kontaktinformationen mit dem Typ ""%1"" senden'"), InformationType);
	EndIf;
	
	If FieldsValues = "" AND IsBlankString(Presentation) Then
		ShowMessageBox(,NStr("ru = 'Для отправки SMS необходимо ввести номер телефона.'; en = 'To send an SMS, enter the phone number.'; pl = 'W celu wysłania wiadomości SMS, należy wpisać numer telefonu.';es_ES = 'Para enviar SMS es necesario introducir el número de teléfono.';es_CO = 'Para enviar SMS es necesario introducir el número de teléfono.';tr = 'SMS göndermek için telefon numarası girilmelidir.';it = 'Per inviare un SMS, compila un numero di telefono';de = 'Um eine SMS zu versenden, müssen Sie eine Telefonnummer eingeben.'"));
		Return;
	EndIf;
	
	XMLData = ContactInformation.XMLData;
	If ValueIsFilled(XMLData) Then
		RecipientNumber = ContactInformationManagementInternalServerCall.ContactInformationCompositionString(XMLData);
	EndIf;
	If NOT ValueIsFilled(RecipientNumber) Then
		RecipientNumber = TrimAll(Presentation);
	EndIf;
	RecipientsNumbers = New Array;
	RecipientsNumbers.Add(RecipientNumber);
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("SenderName", Undefined);
	AdditionalParameters.Insert("Transliterate", False);
	AdditionalParameters.Insert("ContactInformationSource", ContactInformationSource);
	ModuleSendSMSMessageClient = CommonClient.CommonModule("SMSClient");
	ModuleSendSMSMessageClient.SendSMSMessage(RecipientsNumbers, "", AdditionalParameters);
	
EndProcedure

// Makes a call to the passed phone number via SIP telephony, and if it is not available, via Skype.
// 
//
// Parameters:
//  PhoneNumber - String - a phone number to which the call will be made.
//
Procedure Telephone(PhoneNumber) Export
	
	PhoneNumber = StringFunctionsClientServer.ReplaceCharsWithOther("()_- ", PhoneNumber, "");
	
	ProtocolName = "tel"; // use "tel" by default.
	
	#If NOT WebClient Then
		AvailableProtocolName = TelephonyApplicationIsSet();
		If AvailableProtocolName = Undefined Then
			StringWithWarning = New FormattedString(
					NStr("ru = 'Для совершения звонка требуется установить программу телефонии, например'; en = 'To make a call, set a telephony application, for example,'; pl = 'Aby nawiązać połączenie, należy zainstalować aplikację telefonii, np.';es_ES = 'Para llamar se requiere instalar el programa de telefonía, por ejemplo';es_CO = 'Para llamar se requiere instalar el programa de telefonía, por ejemplo';tr = 'Arama yapmak için telefon uygulaması indirilmelidir, örneğin';it = 'Per fare una chiamata, impostare una applicazione telefonica, per esempio,';de = 'Um einen Anruf zu tätigen, müssen Sie ein Telefonie-Programm installieren, zum Beispiel'"),
					 " ", New FormattedString("Skype",,,, "http://www.skype.com"), ".");
			ShowMessageBox(Undefined, StringWithWarning);
			Return;
		ElsIf NOT IsBlankString(AvailableProtocolName) Then
			ProtocolName = AvailableProtocolName;
		EndIf;
	#EndIf
	
	CommandLine = ProtocolName + ":" + PhoneNumber;
	
	Notification = New NotifyDescription("AfterStartApplication", ThisObject);
	CommonClient.OpenURL(CommandLine, Notification);
	
EndProcedure

// Calls via Skype.
//
// Parameters:
//  SkypeUsername - String - a Skype username.
//
Procedure CallSkype(SkypeUsername) Export
	
	OpenSkype("skype:" + SkypeUsername + "?call");

EndProcedure

// Open conversation window (chat) in Skype
//
// Parameters:
//  SkypeUsername - String - a Skype username.
//
Procedure StartCoversationInSkype(SkypeUsername) Export
	
	OpenSkype("skype:" + SkypeUsername + "?chat");
	
EndProcedure

// Opens a contact information reference.
//
// Parameters:
//  FieldsValues - String, Structure, Map, ValueList - contacts.
//  Presentation - String - a presentation. Used if unable to determine presentation based on a parameter.
//                            FieldsValues (the Presentation field is not available).
//  ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes, Structure -
//                      used to determine a type if it is impossible to determine it by the FieldsValues field.
//
Procedure GoToWebLink(Val FieldsValues, Val Presentation = "", ExpectedKind = Undefined) Export
	
	ContactInformation = ContactInformationManagementInternalServerCall.TransformContactInformationXML(
		New Structure("FieldsValues, Presentation, ContactInformationKind", FieldsValues, Presentation, ExpectedKind));
	InformationType = ContactInformation.ContactInformationType;
	
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Нельзя открыть ссылку по контактной информации с типом ""%1""'; en = 'Cannot open a contact information reference with the ""%1"" type'; pl = 'Nie można otworzyć odwołania do informacji kontaktowych dla ""%1"" typu';es_ES = 'No se puede abrir una referencia de la información de contacto para el tipo ""%1""';es_CO = 'No se puede abrir una referencia de la información de contacto para el tipo ""%1""';tr = '""%1"" türü için bir iletişim bilgileri referansı açılamıyor';it = 'Impossibile aprire una riferimento informazione di contatto con il tipo ""%1""';de = 'Eine Kontaktinformationsreferenz für den Typ ""%1"" kann nicht geöffnet werden'"), InformationType);
	EndIf;
		
	XMLData = ContactInformation.XMLData;

	HyperlinkAddress = ContactInformationManagementInternalServerCall.ContactInformationCompositionString(XMLData);
	If TypeOf(HyperlinkAddress) <> Type("String") Then
		Raise NStr("ru = 'Ошибка получения ссылки, неверный тип контактной информации'; en = 'Error getting reference. Invalid contact information type'; pl = 'Wystąpił błąd podczas odbierania referencyjnego, nieprawidłowego typu informacji kontaktowych';es_ES = 'Ha ocurrido un error al recibir la referencia, tipo de la información de contacto incorrecto';es_CO = 'Ha ocurrido un error al recibir la referencia, tipo de la información de contacto incorrecto';tr = 'Referans alınırken bir hata oluştu, iletişim bilgilerin türü yanlış';it = 'Errore nella ricezione di riferimento. Tipo di informazioni di contatto non valido';de = 'Beim Empfang der Referenz ist ein Fehler aufgetreten, falscher Kontaktinformationstyp'");
	EndIf;
	
	If StrFind(HyperlinkAddress, "://") > 0 Then
		CommonClient.OpenURL(HyperlinkAddress);
	Else
		CommonClient.OpenURL("http://" + HyperlinkAddress);
	EndIf;
EndProcedure

// Shows an address in a browser on Yandex.Maps or Google Maps.
//
// Parameters:
//  Address						 - String - text presentation of an address.
//  MapServiceName	 - String - a name of a map service: Yandex.Maps or GoogleMaps.
//
Procedure ShowAddressOnMap(Address, MapServiceName) Export
	AddressCoded = URLEncode(Address);
	If MapServiceName = "GoogleMaps" Then
		CommandLine = "https://maps.google.com/?q=" + AddressCoded;
	Else
		CommandLine = "https://maps.yandex.ru/?text=" + AddressCoded;
	EndIf;
	
	CommonClient.OpenURL(CommandLine);
	
EndProcedure

// Displays a form with history of contacts changes.
//
// Parameters:
//  Form - ClientApplicationForm - a form with contacts.
//  ContactsParameters - Structure - info about contacts item.
//
Procedure OpenHistoryChangeForm(Form, ContactInformationParameters) Export
	
	Result = New Structure("Kind", ContactInformationParameters.Kind);
	FoundRows = Form.ContactInformationAdditionalAttributeDetails.FindRows(Result);
	
	ContactsList = New Array;
	For each ContactInformationRow In FoundRows Do
		ContactInformation = New Structure("Presentation, Value, FieldsValues, ValidFrom, Comment");
		FillPropertyValues(ContactInformation, ContactInformationRow);
		ContactsList.Add(ContactInformation);
	EndDo;
	
	AdditionalParameters = New Structure("Form");
	AdditionalParameters.Insert("ItemName", ContactInformationParameters.AttributeName);
	AdditionalParameters.Insert("Kind", ContactInformationParameters.Kind);
	AdditionalParameters.Insert("ItemForPlacementName", ContactInformationParameters.ItemForPlacementName);
	AdditionalParameters.Form = Form;
	
	FormParameters = New Structure("ContactsList", ContactsList);
	FormParameters.Insert("ContactInformationKind", ContactInformationParameters.Kind);
	FormParameters.Insert("ReadOnly", Form.ReadOnly);

	ClosingNotification = New NotifyDescription("AfterClosingHistoryForm", ContactsManagerClient, AdditionalParameters);
	OpenForm("DataProcessor.ContactInformationInput.Form.ContactInformationHistory", FormParameters, Form,,,, ClosingNotification);
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use OnChange().
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     Item - FormField - a form item containing contacts presentation.
//     IsTabularSection - Boolean - a flag specifying that the item is contained in a form table.
//
Procedure PresentationOnChange(Form, Item, IsTabularSection = False) Export
	OnChange(Form, Item, IsTabularSection);
EndProcedure

// Obsolete. Use StartChoice().
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     Item - FormField - a form item containing contacts presentation.
//     Modified - Boolean - a lag specifying that the form was modified.
//     StandardProcessing - Boolean - a flag specifying that standard processing is required for the form event.
//
// Returns:
//  Undefined - not used, backward compatibility.
//
Function PresentationStartChoice(Form, Item, Modified = True, StandardProcessing = False) Export
	StartChoice(Form, Item, Modified, StandardProcessing);
	Return Undefined;
EndFunction

// Obsolete. Use Clearing().
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     AttrivuteName - String - a name of form attribute related to contacts presentation.
//
// Returns:
//  Undefined - not used, backward compatibility.
//
Function ClearingPresentation(Form, AttributeName) Export
	Clearing(Form, AttributeName);
	Return Undefined;
EndFunction

// Obsolete. Use ExecuteCommand().
//
// Parameters:
//     Form - ClientApplicationForm - a form of a contacts owner.
//     CommandName - String - a name of the automatically generated action command.
//
// Returns:
//  Undefined - not used, backward compatibility.
//
Function AttachableCommand(Form, CommandName) Export
	ExecuteCommand(Form, CommandName);
	Return Undefined;
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Nonmodal dialog completion.

Procedure AfterClosingHistoryForm(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Form = AdditionalParameters.Form;
	
	Filter = New Structure("Kind", AdditionalParameters.Kind);
	FoundRows = Form.ContactInformationAdditionalAttributeDetails.FindRows(Filter);
	
	OldComment = Undefined;
	For each ContactInformationRow In FoundRows Do
		If NOT ContactInformationRow.IsHistoricalContactInformation Then
			OldComment = ContactInformationRow.Comment;
		EndIf;
		Form.ContactInformationAdditionalAttributeDetails.Delete(ContactInformationRow);
	EndDo;
	
	UpdateParameters = New Structure;
	For Each ContactInformationRow In Result.History Do
		RowData = Form.ContactInformationAdditionalAttributeDetails.Add();
		FillPropertyValues(RowData, ContactInformationRow);
		If NOT ContactInformationRow.IsHistoricalContactInformation Then
			If IsBlankString(ContactInformationRow.Presentation)
				AND Result.Property("EditOnlyInDialog")
				AND Result.EditOnlyInDialog Then
					Presentation = ContactsManagerClientServer.EmptyAddressTextAsHiperlink();
			Else
				Presentation = ContactInformationRow.Presentation;
			EndIf;
			Form[AdditionalParameters.ItemName] = Presentation;
			RowData.AttributeName = AdditionalParameters.ItemName;
			RowData.ItemForPlacementName = AdditionalParameters.ItemForPlacementName;
			If RowData.Comment <> OldComment Then
				UpdateParameters.Insert("IsCommentAddition", True);
				UpdateParameters.Insert("ItemForPlacementName", AdditionalParameters.ItemForPlacementName);
				UpdateParameters.Insert("AttributeName", AdditionalParameters.ItemName);
			EndIf;
		EndIf;
	EndDo;
	
	Form.Modified = True;
	If ValueIsFilled(UpdateParameters) Then
		UpdateFormContactInformation(Form, UpdateParameters);
	EndIf;
EndProcedure

Procedure PresentationStartChoiceCompletion(Val ClosingResult, Val AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		If AdditionalParameters.Property("UpdateConextMenu") 
			AND AdditionalParameters.UpdateConextMenu Then
				Result = New Structure();
				Result.Insert("UpdateConextMenu",  True);
				Result.Insert("ItemForPlacementName", AdditionalParameters.PlacementItemName);
				UpdateFormContactInformation(AdditionalParameters.Form, Result);
		EndIf;
		Return;
	EndIf;
	
	FillingData = AdditionalParameters.FillingData;
	DataOnForm    = AdditionalParameters.RowData;
	Result        = AdditionalParameters.Result;
	Item          = AdditionalParameters.Item;
	Form            = AdditionalParameters.Form;
	
	PresentationText = ClosingResult.Presentation;
	FieldsValues      = ClosingResult.ContactInformation;
	Value           = ClosingResult.Value;
	Comment        = ClosingResult.Comment;
	
	If DataOnForm.Property("StoreChangeHistory") AND DataOnForm.StoreChangeHistory Then
		ContactInformationAdditionalAttributeDetails = FillingData.ContactInformationAdditionalAttributeDetails;
		Filter = New Structure("Kind", DataOnForm.Kind);
		FoundRows = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		For Each ContactInformationRow In FoundRows Do
			ContactInformationAdditionalAttributeDetails.Delete(ContactInformationRow);
		EndDo;
		
		Filter = New Structure("Kind", DataOnForm.Kind);
		FoundRows = ClosingResult.ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		
		If FoundRows.Count() > 1 Then
			
			StringWithValidAddress = Undefined;
			MinDate = Undefined;
			
			For Each ContactInformationRow In FoundRows Do
				
				NewContactInformation = ContactInformationAdditionalAttributeDetails.Add();
				FillPropertyValues(NewContactInformation, ContactInformationRow);
				NewContactInformation.ItemForPlacementName = AdditionalParameters.PlacementItemName;
				
				If StringWithValidAddress = Undefined
					OR ContactInformationRow.ValidFrom > StringWithValidAddress.ValidFrom Then
						StringWithValidAddress = ContactInformationRow;
				EndIf;
				If MinDate = Undefined
					OR ContactInformationRow.ValidFrom < MinDate Then
						MinDate = ContactInformationRow.ValidFrom;
				EndIf;
				
			EndDo;
			
			// Correcting invalid addresses without the original date of filling
			If ValueIsFilled(MinDate) Then
				Filter = New Structure("ValidFrom", MinDate);
				StringsWithMinDate = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
				If StringsWithMinDate.Count() > 0 Then
					StringsWithMinDate[0].ValidFrom = Date(1, 1, 1);
				EndIf;
			EndIf;
			
			If StringWithValidAddress <> Undefined Then
				PresentationText = StringWithValidAddress.Presentation;
				FieldsValues      = StringWithValidAddress.FieldsValues;
				Value           = StringWithValidAddress.Value;
				Comment        = StringWithValidAddress.Comment;
			EndIf;
			
		ElsIf FoundRows.Count() = 1 Then
			NewContactInformation = ContactInformationAdditionalAttributeDetails.Add();
			FillPropertyValues(NewContactInformation, FoundRows[0],, "ValidFrom");
			NewContactInformation.ItemForPlacementName = AdditionalParameters.PlacementItemName;
			DataOnForm.ValidFrom = Date(1, 1, 1);
		EndIf;
		
	EndIf;
	
	If AdditionalParameters.IsTabularSection Then
		FillingData[Item.Name + "Value"]      = ClosingResult.Value;
		
	Else
		Form.Items.Find(Item.Name).ExtendedToolTip.Title = Comment;
		
		DataOnForm.Presentation = PresentationText;
		DataOnForm.Value      = ClosingResult.Value;
		DataOnForm.Comment   = Comment;
	EndIf;
	
	If ClosingResult.Property("AddressAsHyperlink")
		AND ClosingResult.AddressAsHyperlink
		AND NOT ValueIsFilled(PresentationText) Then
			FillingData[Item.Name] = ContactsManagerClientServer.EmptyAddressTextAsHiperlink();
	Else
		FillingData[Item.Name] = PresentationText;
	EndIf;
	
	If ClosingResult.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Result.Insert("UpdateConextMenu", True);
	EndIf;
	
	Form.Modified = True;
	UpdateFormContactInformation(Form, Result);
EndProcedure

Procedure ContactInformationAddInputFieldCompletion(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then
		// Canceling selection
		Return;
	EndIf;
	
	Result = New Structure();
	Result.Insert("KindToAdd", SelectedItem.Value);
	Result.Insert("ItemForPlacementName", AdditionalParameters.ItemForPlacementName);
	Result.Insert("CommandName", AdditionalParameters.CommandName);
	If SelectedItem.Value.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Result.Insert("UpdateConextMenu", True);
	EndIf;
	
	UpdateFormContactInformation(AdditionalParameters.Form, Result);
EndProcedure

Procedure AfterStartApplication(ApplicationStarted, Parameters) Export
	
	If Not ApplicationStarted Then 
		StringWithWarning = New FormattedString(
			NStr("ru = 'Для совершения звонка требуется установить программу телефонии, например'; en = 'To make a call, set a telephony application, for example,'; pl = 'Aby nawiązać połączenie, należy zainstalować aplikację telefonii, np.';es_ES = 'Para llamar se requiere instalar el programa de telefonía, por ejemplo';es_CO = 'Para llamar se requiere instalar el programa de telefonía, por ejemplo';tr = 'Arama yapmak için telefon uygulaması indirilmelidir, örneğin';it = 'Per fare una chiamata, impostare una applicazione telefonica, per esempio,';de = 'Um einen Anruf zu tätigen, müssen Sie ein Telefonie-Programm installieren, zum Beispiel'"),
			 " ", New FormattedString("Skype",,,, "http://www.skype.com"), ".");
		ShowMessageBox(Undefined, StringWithWarning);
	EndIf;
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////

// Completes the modal dialog for email creation.
Procedure CreateContactInformationEmailCompletion(Action, MailAddr) Export
	
	CommonClient.OpenURL("mailto:" + MailAddr);
	
EndProcedure

#EndRegion

#Region Private

Procedure AfterChoiceFromPhoneMenu(SelectedItem, Parameters) Export
	
	If SelectedItem <> Undefined Then
		If SelectedItem.Value = "SendSMSMessage" Then
			CreateSMSMessage("", Parameters.PhoneNumber, Parameters.ContactInformationType, Parameters.ContactInformationSource);
		Else
			Telephone(Parameters.PhoneNumber);
		EndIf;
	EndIf;
EndProcedure

Procedure AfterChoiceFromSkypeMenu(SelectedItem, Parameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	If SelectedItem.Value = "Call" Then
		CallSkype(Parameters.SkypeUsername);
	ElsIf SelectedItem.Value = "StartChat" Then
		StartCoversationInSkype(Parameters.SkypeUsername);
	EndIf;

EndProcedure

Procedure OpenSkype(CommandLine)
	
	#If NOT WebClient Then
		If IsBlankString(TelephonyApplicationIsSet("skype")) Then
			ShowMessageBox(Undefined, NStr("ru = 'Для совершения звонка по Skype требуется установить программу.'; en = 'To make a Skype call, install the application.'; pl = 'Aby nawiązać połączenie przez Skype, musisz zainstalować program.';es_ES = 'Para hacer una llamada en Skype, se requiere instalar el programa.';es_CO = 'Para hacer una llamada en Skype, se requiere instalar el programa.';tr = 'Skype araması yapmak için programı yüklemeniz gerekir.';it = 'Per fare una chiamata Skype, installare l''applicazione.';de = 'Um einen Anruf über Skype zu tätigen, ist es erforderlich, das Programm zu installieren.'"));
			Return;
		EndIf;
	#EndIf
	
	Notification = New NotifyDescription("AfterStartApplication", ThisObject);
	CommonClient.OpenURL(CommandLine, Notification);
	
EndProcedure

// Returns a string of additional values by attribute name.
//
// Parameters:
//    Form - ClientApplicationForm - a passed form.
//    Item - FormDataStructureAndCollection - form data.
//
// Returns:
//    StringCollection - found data.
//    Undefined - if no data available.
//
Function GetAdditionalValueString(Form, Item, IsTabularSection = False)
	
	Filter = New Structure("AttributeName", Item.Name);
	Rows = Form.ContactInformationAdditionalAttributeDetails.FindRows(Filter);
	RowData = ?(Rows.Count() = 0, Undefined, Rows[0]);
	
	If IsTabularSection AND RowData <> Undefined Then
		
		PathToString = Form.Items[Form.CurrentItem.Name].CurrentData;
		
		RowData.Presentation = PathToString[Item.Name];
		RowData.Value      = PathToString[Item.Name + "Value"];
		
	EndIf;
	
	Return RowData;
	
EndFunction

// Processes entering a comment using the context menu.
Procedure EnterComment(Val Form, Val AttributeName, Val FoundRow, Val Result)
	Comment = FoundRow.Comment;
	
	Notification = New NotifyDescription("EnterCommentCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Form", Form);
	Notification.AdditionalParameters.Insert("CommentAttributeName", "Comment" + AttributeName);
	Notification.AdditionalParameters.Insert("FoundRow", FoundRow);
	Notification.AdditionalParameters.Insert("PreviousComment", Comment);
	Notification.AdditionalParameters.Insert("Result", Result);
	Notification.AdditionalParameters.Insert("ItemForPlacementName", FoundRow.ItemForPlacementName);
	
	CommonClient.ShowMultilineTextEditingForm(Notification, Comment, 
		NStr("ru = 'Комментарий'; en = 'Comment'; pl = 'Uwagi';es_ES = 'Comentario';es_CO = 'Comentario';tr = 'YORUM';it = 'Commento';de = 'Kommentar'"));
EndProcedure

// Completes a nonmodal dialog.
Procedure EnterCommentCompletion(Val Comment, Val AdditionalParameters) Export
	If Comment = Undefined Or Comment = AdditionalParameters.PreviousComment Then
		// Canceling entry or no changes.
		Return;
	EndIf;
	
	CommentWasEmpty  = IsBlankString(AdditionalParameters.PreviousComment);
	CommentBecameEmpty = IsBlankString(Comment);
	
	AdditionalParameters.FoundRow.Comment = Comment;
	
	If CommentWasEmpty AND Not CommentBecameEmpty Then
		AdditionalParameters.Result.Insert("IsCommentAddition", True);
	ElsIf Not CommentWasEmpty AND CommentBecameEmpty Then
		AdditionalParameters.Result.Insert("IsCommentAddition", False);
	Else
		If AdditionalParameters.Form.Items.Find(AdditionalParameters.CommentAttributeName) <> Undefined Then
			Item = AdditionalParameters.Form.Items[AdditionalParameters.CommentAttributeName];
			Item.Title = Comment;
		Else
			AdditionalParameters.Result.Insert("IsCommentAddition", True);
		EndIf;
	EndIf;
	
	AdditionalParameters.Form.Modified = True;
	UpdateFormContactInformation(AdditionalParameters.Form, AdditionalParameters.Result)
EndProcedure

// Context call
Procedure UpdateFormContactInformation(Form, Result)

	Form.Attachable_UpdateContactInformation(Result);
	
EndProcedure

Procedure OnContactsChange(Form, Item, IsTabularSection, UpdateForm)
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	// Clearing presentation if clearing is required.
	RowData = GetAdditionalValueString(Form, Item, IsTabularSection);
	If RowData = Undefined Then 
		Return;
	EndIf;
	
	Text = Item.EditText;
	If IsBlankString(Text) Then
		
		FillingData[Item.Name] = "";
		If IsTabularSection Then
			FillingData[Item.Name + "Value"] = "";
		EndIf;
		RowData.Presentation = "";
		RowData.Value      = "";
		Result = New Structure("UpdateConextMenu, ItemForPlacementName", True, RowData.ItemForPlacementName);
		If UpdateForm Then
			UpdateConextMenu(Form, RowData.ItemForPlacementName);
		EndIf;
		Return;
		
	EndIf;
	
	If RowData.Property("StoreChangeHistory")
		AND RowData.StoreChangeHistory
		AND BegOfDay(RowData.ValidFrom) <> BegOfDay(CommonClient.SessionDate()) Then
		HistoricalContacts = Form.ContactInformationAdditionalAttributeDetails.Add();
		FillPropertyValues(HistoricalContacts, RowData);
		HistoricalContacts.IsHistoricalContactInformation = True;
		HistoricalContacts.AttributeName = "";
		RowData.ValidFrom = BegOfDay(CommonClient.SessionDate());
	EndIf;
	
	RowData.Value = ContactInformationManagementInternalServerCall.ContactsByPresentation(Text, RowData.Kind);
	RowData.Presentation = Text;
	
	If IsTabularSection Then
		FillingData[Item.Name + "Value"]      = RowData.Value;
	EndIf;
	
	If RowData.Type = PredefinedValue("Enum.ContactInformationTypes.Address") AND UpdateForm Then
		Result = New Structure("UpdateConextMenu, ItemForPlacementName", True, RowData.ItemForPlacementName);
		UpdateFormContactInformation(Form, Result)
	EndIf;

EndProcedure

Function IsTabularSection(Item)
	
	Parent = Item.Parent;
	
	While TypeOf(Parent) <> Type("ClientApplicationForm") Do
		
		If TypeOf(Parent) = Type("FormTable") Then
			Return True;
		EndIf;
		
		Parent = Parent.Parent;
		
	EndDo;
	
	Return False;
	
EndFunction

// determining context menu commands.
Function ContextMenuCommand(CommandName)
	
	Result = New Structure("Command, MovementDirection, AttributeName", Undefined, 0, Undefined);
	
	AttributeName = ?(StrStartsWith(CommandName, "ContextMenuSubmenu"),
		StrReplace(CommandName, "ContextMenuSubmenu", ""), StrReplace(CommandName, "ContextMenu", ""));
		
	If StrStartsWith(AttributeName, "Up") Then
		Result.AttributeName = StrReplace(AttributeName, "Up", "");
		Result.MovementDirection = -1;
		Result.Command = "Up";
	ElsIf StrStartsWith(AttributeName, "History") Then
		Result.AttributeName = StrReplace(AttributeName, "History", "");
		Result.Command = "History";
	ElsIf StrStartsWith(AttributeName, "Down") Then
		Result.AttributeName = StrReplace(AttributeName, "Down", "");
		Result.MovementDirection = 1;
		Result.Command = "Down";
	ElsIf StrStartsWith(AttributeName, "YandexMap") Then
		Result.AttributeName = StrReplace(AttributeName, "YandexMap", "");
		Result.Command = "YandexMap";
	ElsIf StrStartsWith(AttributeName, "GoogleMap") Then
		Result.AttributeName = StrReplace(AttributeName, "GoogleMap", "");
		Result.Command = "GoogleMap";
	Else
		Result.AttributeName = StrReplace(AttributeName, "Comment", "");
		Result.Command = "Comment";
	EndIf;
	
	Return Result;
	
EndFunction

// Checks whether the telephony application is set on the computer. 
//  Checks is available only in the thin client for Windows.
//
// Parameters:
//  ProtocolName - String - a name of the URI protocol to be checked, available options: skype, tel, sip.
//                          If the parameter is not specified, all protocols will be checked.
// 
// Returns:
//  String - a name of the available URI protocol is registered in the registry. Empty string - if protocol is unavailable.
//  Undefined if check cannot be performed.
//
Function TelephonyApplicationIsSet(ProtocolName = Undefined)
	
	If CommonClientServer.IsWindowsClient() Then
		If ValueIsFilled(ProtocolName) Then
			Return ?(ProtocolNameRegisteredInRegistry(ProtocolName), ProtocolName, "");
		Else
			ProtocolsList = New Array;
			ProtocolsList.Add("tel");
			ProtocolsList.Add("sip");
			ProtocolsList.Add("skype");
			For each ProtocolName In ProtocolsList Do
				If ProtocolNameRegisteredInRegistry(ProtocolName) Then
					Return ProtocolName;
				EndIf;
			EndDo;
			Return Undefined;
		EndIf;
	EndIf;
	
	// Consider that the application is always available for Linux and MacOS.
	// if an error occurred, it will be processed during startup.
	Return ProtocolName;
EndFunction

Function ProtocolNameRegisteredInRegistry(ProtocolName)
	
	Try
		Shell = New COMObject("Wscript.Shell");
		Shell.RegRead("HKEY_CLASSES_ROOT\" + ProtocolName + "\");
	Except
		Return False;
	EndTry;
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Returns the string in which all non-alphanumeric chars (except -_.) are replaced by the percent 
// sign (%) followed by two hexadecimal digits and spaces encoded as plus signs (+). The string is 
// encoded in the same way as the post data of WWW form, that is, as in the 
// application/x-www-form-urlencoded media type.

Function URLEncode(Row) 
	Result = "";
	For CharNumber = 1 To StrLen(Row) Do
		CharCode = CharCode(Row, CharNumber);
		Char = Mid(Row, CharNumber, 1);
		
		// ignore A...Z, a...z, 0...9
		If StrFind("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", Char) > 0 Then // chars -_.!~*\() encode as unsafe
			Result = Result + Char;
			Continue;
		EndIf;
		
		If Char = " " Then
			Result = Result + "+";
			Continue;
		EndIf;
		
		If CharCode <= 127 Then // 0x007F
			Result = Result + BytePresentation(CharCode);
		ElsIf CharCode <= 2047 Then // 0x07FF 
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayInNumber(
																LogicalBitwiseOr(
																			 NumberInBinaryArray(192,8),
																			 NumberInBinaryArray(Int(CharCode / Pow(2,6)),8)))); // 0xc0 | (ch >> 6)
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayInNumber(
										   						LogicalBitwiseOr(
																			 NumberInBinaryArray(128,8),
																			 LogicalBitwiseAnd(
																			 			NumberInBinaryArray(CharCode,8),
																						NumberInBinaryArray(63,8)))));  //0x80 | (ch & 0x3F)
		Else  // 0x7FF < ch <= 0xFFFF
			Result = Result 
					  + BytePresentation	(
					  						 BinaryArrayInNumber(
																  LogicalBitwiseOr(
																			   NumberInBinaryArray(224,8), 
																			   NumberInBinaryArray(Int(CharCode / Pow(2,12)),8)))); // 0xe0 | (ch >> 12)
											
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayInNumber(
										   						LogicalBitwiseOr(
																			 NumberInBinaryArray(128,8),
																			 LogicalBitwiseAnd(
																			 			NumberInBinaryArray(Int(CharCode / Pow(2,6)),8),
																						NumberInBinaryArray(63,8)))));  //0x80 | ((ch >> 6) & 0x3F)
											
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayInNumber(
										   						LogicalBitwiseOr(
																			 NumberInBinaryArray(128,8),
																			 LogicalBitwiseAnd(
																			 			NumberInBinaryArray(CharCode,8),
																						NumberInBinaryArray(63,8)))));  //0x80 | (ch & 0x3F)
								
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function BytePresentation(Val Byte)
	Result = "";
	CharactersString = "0123456789ABCDEF";
	For Counter = 1 To 2 Do
		Result = Mid(CharactersString, Byte % 16 + 1, 1) + Result;
		Byte = Int(Byte / 16);
	EndDo;
	Return "%" + Result;
EndFunction

Function NumberInBinaryArray(Val Number, Val TotalDigits = 32)
	Result = New Array;
	CurrentDigit = 0;
	While CurrentDigit < TotalDigits Do
		CurrentDigit = CurrentDigit + 1;
		Result.Add(Boolean(Number % 2));
		Number = Int(Number / 2);
	EndDo;
	Return Result;
EndFunction

Function BinaryArrayInNumber(Array)
	Result = 0;
	For DigitNumber = -(Array.Count()-1) To 0 Do
		Result = Result * 2 + Number(Array[-DigitNumber]);
	EndDo;
	Return Result;
EndFunction

Function LogicalBitwiseAnd(BinaryArray1, BinaryArray2)
	Result = New Array;
	For Index = 0 To BinaryArray1.Count()-1 Do
		Result.Add(BinaryArray1[Index] AND BinaryArray2[Index]);
	EndDo;	
	Return Result;
EndFunction

Function LogicalBitwiseOr(BinaryArray1, BinaryArray2)
	Result = New Array;
	For Index = 0 To BinaryArray1.Count()-1 Do
		Result.Add(BinaryArray1[Index] Or BinaryArray2[Index]);
	EndDo;	
	Return Result;
EndFunction

Procedure UpdateConextMenu(Form, ItemForPlacementName)
	
	ContactInformationParameters = Form.ContactInformationParameters[ItemForPlacementName];
	AllRows = Form.ContactInformationAdditionalAttributeDetails;
	FoundRows = AllRows.FindRows( 
		New Structure("Type, IsTabularSectionAttribute", PredefinedValue("Enum.ContactInformationTypes.Address"), False));
		
	TotalNumberOfCommands = 0;
	For Each CIRow In AllRows Do
		
		If TotalNumberOfCommands > 50 Then // Restriction for a large number of addresses on the form
			Break;
		EndIf;
		
		If CIRow.Type <> PredefinedValue("Enum.ContactInformationTypes.Address") Then
			Continue;
		EndIf;
		
		SubmenuCopyAddresses = Form.Items.Find("SubmenuCopyAddresses" + CIRow.AttributeName);
		ContextSubmenuCopyAddresses = Form.Items.Find("ContextSubmenuCopyAddresses" + CIRow.AttributeName);
		If SubmenuCopyAddresses <> Undefined AND ContextSubmenuCopyAddresses = Undefined Then
			Continue;
		EndIf;
			
		CommandNumerInSubmenu = 0;
		AddressListInSubmenu = New Map();
		AddressListInSubmenu.Insert(Upper(CIRow.Presentation), True);
		
		For Each Address In FoundRows Do
			
			If CommandNumerInSubmenu > 7 Then // Restriction for a large number of addresses on the form
				Break;
			EndIf;
			
			If Address.IsHistoricalContactInformation Or Address.AttributeName = CIRow.AttributeName Then
				Continue;
			EndIf;
			
			CommandName = "MenuSubmenuAddress" + CIRow.AttributeName + "_" + Address.AttributeName;
			Command = Form.Commands.Find(CommandName);
			If Command = Undefined Then
				Command = Form.Commands.Add(CommandName);
				Command.ToolTip = NStr("ru = 'Скопировать адрес'; en = 'Copy address'; pl = 'Skopiować adres';es_ES = 'Copiar la dirección';es_CO = 'Copiar la dirección';tr = 'Adresi kopyala';it = 'Copia indirizzo';de = 'Adresse kopieren'");
				Command.Action = "Attachable_ContactInformationExecuteCommand";
				Command.ModifiesStoredData = True;
				
				ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
				CommandNumerInSubmenu = CommandNumerInSubmenu + 1;
			EndIf;
			
			AddressPresentation = ?(CIRow.InternationalAddressFormat,
				StringFunctionsClientServer.LatinString(Address.Presentation), Address.Presentation);
			
			If AddressListInSubmenu[Upper(Address.Presentation)] <> Undefined Then
				AddressPresentation = "";
			Else
				AddressListInSubmenu.Insert(Upper(Address.Presentation), True);
			EndIf;
			
			If SubmenuCopyAddresses <> Undefined Then
				AddButtonCopeAddress(Form, CommandName,
					AddressPresentation, ContactInformationParameters, SubmenuCopyAddresses);
				EndIf;
				
			If ContextSubmenuCopyAddresses <> Undefined Then
				AddButtonCopeAddress(Form, CommandName, 
					AddressPresentation, ContactInformationParameters, ContextSubmenuCopyAddresses);
			EndIf;
			
		EndDo;
		TotalNumberOfCommands = TotalNumberOfCommands + CommandNumerInSubmenu;
	EndDo;
	
EndProcedure

Procedure AddButtonCopeAddress(Form, CommandName, ItemTitle, ContactInformationParameters, Submenu)
	
	ItemName = Submenu.Name + "_" + CommandName;
	Button = Form.Items.Find(ItemName);
	If Button = Undefined Then
		Button = Form.Items.Add(ItemName, Type("FormButton"), Submenu);
		Button.CommandName = CommandName;
		ContactInformationParameters.AddedItems.Add(ItemName, 1);
	EndIf;
	Button.Title = ItemTitle;
	Button.Visible = ValueIsFilled(ItemTitle);

EndProcedure

#EndRegion
