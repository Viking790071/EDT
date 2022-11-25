
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TypeArray = New Array;
	TypeArray.Add(Type("String"));
	Items.ContactRecipients.TypeRestriction = New TypeDescription(TypeArray, New StringQualifiers(100));
	Items.Subject.TypeRestriction 			   = New TypeDescription(TypeArray, New StringQualifiers(200));
	
	SMSProvider = Constants.SMSProvider.Get();
	SMSSettingsComplete = SMS.SMSMessageSendingSetupCompleted();
	AvailableRightSettingsSMS = Users.IsFullUser();
	CharactersLeft = GenerateCharacterQuantityLabel(SendTransliterated, Object.Content);
	
	If Parameters.Key.IsEmpty() Then
		FillNewMessageDefault();
		HandlePassedParameters(Parameters, Cancel);
	EndIf;
	
	// Subject history for automatic selection
	ImportSubjectHistoryByString();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesGroup");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
EndProcedure

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If TypeOf(CurrentObject.Subject) = Type("String") Then
	// Save subjects in history for automatic selection
		
		HistoryItem = SubjectRowHistory.FindByValue(TrimAll(CurrentObject.Subject));
		If HistoryItem <> Undefined Then
			SubjectRowHistory.Delete(HistoryItem);
		EndIf;
		SubjectRowHistory.Insert(0, TrimAll(CurrentObject.Subject));
		
		While SubjectRowHistory.Count() > 30 Do
			SubjectRowHistory.Delete(SubjectRowHistory.Count() - 1);
		EndDo;
		
		Common.CommonSettingsStorageSave("ThemeEventsChoiceList", , SubjectRowHistory.UnloadValues());
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Title = "";
	AutoTitle = True;
	
EndProcedure

// Procedure - event handler FillCheckProcessingAtServer.
//
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.Participants.Count() = 0 Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Recipient list is not filled in.'; ru = 'Список получателей не заполнен.';pl = 'Nie wypełniono listy odbiorców.';es_ES = 'Lista de destinatarios no está rellenada.';es_CO = 'Lista de destinatarios no está rellenada.';tr = 'Alıcı listesi doldurulmadı.';it = 'Elenco dei destinatari non è compilato in.';de = 'Die Empfängerliste ist nicht ausgefüllt.'"),
			,
			"Object.Participants",
			,
			Cancel);
	EndIf;
	
	If IsBlankString(Object.Content) Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Content is not filled in.'; ru = 'Не заполнен текст сообщения.';pl = 'Nie wypełniono pola ""Zawartość"".';es_ES = 'Contenido no está rellenado.';es_CO = 'Contenido no está rellenado.';tr = 'İçerik doldurulmadı.';it = 'Il campo ""Contenuto"" non è compilato.';de = 'Der Inhalt ist nicht ausgefüllt'"),
			,
			"Object.Content",
			,
			Cancel);
	EndIf;
	
	CheckAndConvertRecipientNumbers(Cancel);
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties

EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers
&AtClient
Procedure SubjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	If TypeOf(Object.Subject) = Type("CatalogRef.EventsSubjects") AND ValueIsFilled(Object.Subject) Then
		FormParameters.Insert("CurrentRow", Object.Subject);
	EndIf;
	
	OpenForm("Catalog.EventsSubjects.ChoiceForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure SubjectChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If ValueIsFilled(ValueSelected) Then
		Object.Subject = ValueSelected;
		FillContentEvents(ValueSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure SubjectAutoSelection(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		
		StandardProcessing = False;
		ChoiceData = GetSubjectChoiceList(Text, SubjectRowHistory);
		
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionStart of RecipientsContact item.
//
&AtClient
Procedure RecipientsContactStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("CIType", "Phone");
	If ValueIsFilled(Items.Recipients.CurrentData.Contact) Then
		Contact = Object.Participants.FindByID(Items.Recipients.CurrentRow).Contact;
		If TypeOf(Contact) = Type("CatalogRef.Counterparties") Then
			FormParameters.Insert("CurrentCounterparty", Contact);
		EndIf;
	EndIf;
	NotifyDescription = New NotifyDescription("RecipientsContactSelectionEnd", ThisForm);
	OpenForm("CommonForm.AddressBook", FormParameters, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - event handler SelectionDataProcessor of RecipientsContact item.
//
&AtClient
Procedure RecipientsContactChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If TypeOf(ValueSelected) = Type("CatalogRef.Counterparties") Or TypeOf(ValueSelected) = Type("CatalogRef.ContactPersons") Then
	// Selection is implemented by automatic selection mechanism
		
		Object.Participants.FindByID(Items.Recipients.CurrentRow).Contact = ValueSelected;
		
	EndIf;
	
EndProcedure

// Procedure - event handler AutomaticSelection of RecipientsContact item.
//
&AtClient
Procedure ContactRecipientsAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		StandardProcessing = False;
		ChoiceData = GetContactChoiceList(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendTransliteratedOnChange(Item)
	
	CharactersLeft = GenerateCharacterQuantityLabel(SendTransliterated, Object.Content);
	
EndProcedure

&AtClient
Procedure ContentTextEntryEnd(Item, Text, ChoiceData, Parameters, StandardProcessing)
	
	CharactersLeft = GenerateCharacterQuantityLabel(SendTransliterated, Text);
	Object.Content = Text;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - Send command handler.
//
&AtClient
Procedure Send(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	If SMSSettingsComplete Then
		SMSSendingSettingsAreExecuted();
	Else
		If AvailableRightSettingsSMS Then
			OpenForm("CommonForm.OutboundSMSSettings",,ThisForm,,,,New NotifyDescription("SMSSendingCheckSettings", ThisObject), FormWindowOpeningMode.LockOwnerWindow);
		Else
			MessageText = NStr("en = 'To send SMS, it is necessary to configure sending parameters.
			                   |Address to the administrator to perform settings.'; 
			                   |ru = 'Для отправки SMS требуется настройка параметров отправки.
			                   |Для выполнения настроек обратитесь к администратору.';
			                   |pl = 'Aby przesłać SMS należy skonfigurować parametry wysyłania.
			                   |W celu wybrania ustawień skontaktuj się z administratorem.';
			                   |es_ES = 'Para enviar un SMS, es necesario configurar los parámetros de envío.
			                   |Dirección al administrador para realizar las configuraciones.';
			                   |es_CO = 'Para enviar un SMS, es necesario configurar los parámetros de envío.
			                   |Dirección al administrador para realizar las configuraciones.';
			                   |tr = 'SMS göndermek için gönderme parametrelerini yapılandırmak gereklidir. 
			                   |Ayarları gerçekleştirmek için yöneticiye başvurun.';
			                   |it = 'Per inviare SMS, è necessario configurare i parametri di invio.
			                   |Chiedere all''amministratore di inserire le impostazioni.';
			                   |de = 'Um SMS zu senden, müssen Sendeparameter konfiguriert werden.
			                   |Wenden Sie sich an den Administrator, um Einstellungen vorzunehmen.'");
			ShowMessageBox(, MessageText);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshDeliveryStatuses(Command)
	
	UpdateDeliveryStatusesAtServer();
	
EndProcedure

&AtClient
Procedure FillContent(Command)
	
	If ValueIsFilled(Object.Subject) Then
		FillContentEvents(Object.Subject);
	EndIf;
	
EndProcedure

#EndRegion

#Region CommonProceduresAndFunctions

// Procedure fills the attribute values of a new email by default.
//
&AtServer
Procedure FillNewMessageDefault()
	
	AutoTitle = False;
	Title = "Event: " + Object.EventType + " (Create)";
	
	Object.EventBegin = '00010101';
	Object.EventEnding = '00010101';
	Object.Author = Users.AuthorizedUser();
	Object.Responsible = Drivereuse.GetValueByDefaultUser(Object.Author, "MainResponsible");
	
	SMSMessageSendingSettings = SendSMSMessagesCached.SMSMessageSendingSettings();
	If SMSMessageSendingSettings.SenderName = Undefined Then
		Object.SMSSenderName = "";
	Else
		Object.SMSSenderName = SMSMessageSendingSettings.SenderName;
	EndIf;
	
EndProcedure

// Procedure fills attributes by passed to the form parameters.
//
// Parameters:
//  Parameters	 - Structure	 - Refusal form parameters		 - Boolean	 - Refusal flag
&AtServer
Procedure HandlePassedParameters(Parameters, Cancel)
	
	If Not IsBlankString(Parameters.Text) Then
		
		Object.Content = Parameters.Text;
		
	EndIf;
	
	If Parameters.Recipients <> Undefined Then
		
		If TypeOf(Parameters.Recipients) = Type("String") AND Not IsBlankString(Parameters.Recipients) Then
			
			NewRow = Object.Participants.Add();
			NewRow.HowToContact = Parameters.Whom;
			
		ElsIf TypeOf(Parameters.Recipients) = Type("ValueList") Then
			
			For Each ItemOfList In Parameters.Recipients Do
				NewRow = Object.Participants.Add();
				NewRow.Contact = ItemOfList.Presentation;
				NewRow.HowToContact  = ItemOfList.Value;
			EndDo;
			
		ElsIf TypeOf(Parameters.Recipients) = Type("Array") Then
			
			For Each ArrayElement In Parameters.Recipients Do
				
				NewRow = Object.Recipients.Add();
				NewRow.Contact = ArrayElement.ContactInformationSource;
				NewRow.HowToContact = ArrayElement.Phone;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	If Parameters.Property("SendTransliterated") Then
		SendTransliterated = Parameters.SendTransliterated;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GenerateCharacterQuantityLabel(SendTransliterated, val MessageText)
	
	CharactersInMessage = ?(SendTransliterated, 140, 66);
	CharsCount = StrLen(MessageText);
	MessageCount   = Int(CharsCount / CharactersInMessage) + 1;
	CharactersLeft      = CharactersInMessage - CharsCount % CharactersInMessage;
	MessageTextTemplate = NStr("en = 'Message - %1, characters left - %2'; ru = 'Сообщение - %1, осталось символов - %2';pl = 'Wiadomość - %1, pozostało symboli - %2';es_ES = 'Mensaje - %1, quedan símbolos - %2';es_CO = 'Mensaje - %1, quedan símbolos - %2';tr = 'Mesaj - %1, kalan karakterler - %2';it = 'Messaggio -%1, caratteri rimasti - %2';de = 'Nachricht - %1, übrige Zeichen - %2'");
	
	Return StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, MessageCount, CharactersLeft);
	
EndFunction

&AtServer
Procedure CheckAndConvertRecipientNumbers(Cancel)
	
	For Each Recipient In Object.Participants Do
		
		If IsBlankString(Recipient.HowToContact) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Phone number is not populated.'; ru = 'Поле ""Номер телефона"" не заполнено.';pl = 'Nie wypełniono pola ""Numer telefonu""';es_ES = 'Número de teléfono no está poblado.';es_CO = 'Número de teléfono no está poblado.';tr = 'Telefon numarası doldurulmadı.';it = 'Numero di telefono non popolato.';de = 'Die Telefonnummer ist nicht ausgefüllt.'"),
				,
				CommonClientServer.PathToTabularSection("Object.Participants", Recipient.LineNumber, "HowToContact"),
				,
				Cancel);
			Continue;
		EndIf;
		
		If StringFunctionsClientServer.SplitStringIntoSubstringsArray(Recipient.HowToContact, ";", True).Count() > 1 Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Only one phone number should be specified.'; ru = 'Должен быть указан только один номер телефона.';pl = 'Należy określić tylko jeden numer telefonu.';es_ES = 'Solo un número de teléfono tiene que estar especificado.';es_CO = 'Solo un número de teléfono tiene que estar especificado.';tr = 'Sadece bir telefon numarası belirtilmelidir.';it = 'Un solo numero di telefono deve essere specificato.';de = 'Es sollte nur eine Telefonnummer angegeben werden.'"),
				,
				CommonClientServer.PathToTabularSection("Object.Participants", Recipient.LineNumber, "HowToContact"),
				,
				Cancel);
			Continue;
		EndIf;
		
		Recipient.NumberForSending = DriveClientServer.ConvertNumberForSMSSending(Recipient.HowToContact);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SMSSendingCheckSettings(ClosingResult, AdditionalParameters) Export
	
	SMSSettingsComplete = SMSSettingsAreCompletedServer(SMSProvider);
	If SMSSettingsComplete Then
		SMSSendingSettingsAreExecuted();
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SMSSettingsAreCompletedServer(SMSProvider)
	
	SMSProvider = Constants.SMSProvider.Get();
	Return SMS.SMSMessageSendingSetupCompleted();
	
EndFunction

&AtClient
Procedure SMSSendingSettingsAreExecuted()
	
	ErrorDescription = ExecuteSMSSending();
	
	If IsBlankString(ErrorDescription) Then
		Object.Status = PredefinedValue("Catalog.JobAndEventStatuses.Completed");
		Object.Date = CommonClient.SessionDate();
		Object.EventBegin = Object.Date;
		Object.EventEnding = Object.Date;
		Write();
		ShowUserNotification(NStr("en = 'SMS successfully sent'; ru = 'SMS успешно отправлено';pl = 'SMS wysłany pomyślnie';es_ES = 'SMS se ha enviado con éxito';es_CO = 'SMS se ha enviado con éxito';tr = 'SMS başarı ile gönderildi';it = 'SMS inviato con successo';de = 'Die SMS wurde erfolgreich versendet'"), GetURL(Object.Ref), String(Object.Ref), PictureLib.Information32);
		Close();
	Else
		CommonClientServer.MessageToUser(ErrorDescription,,"Object");
	EndIf;
	
EndProcedure

&AtServer
Function ExecuteSMSSending()
	
	ArrayOfNumbers     = Object.Participants.Unload(,"NumberForSending").UnloadColumn("NumberForSending");
	SendingResult = SMS.SendSMSMessage(ArrayOfNumbers, Object.Content, Object.SMSSenderName, SendTransliterated);
	
	For Each SentMessage In SendingResult.SentMessages Do
		For Each FoundString In Object.Participants.FindRows(New Structure("NumberForSending", SentMessage.RecipientNumber)) Do
			FoundString.MessageID = SentMessage.MessageID;
			FoundString.DeliveryStatus         = Enums.SMSStatus.Outgoing;
		EndDo;
	EndDo;
	
	Return SendingResult.ErrorDescription;
	
EndFunction

&AtServer
Procedure UpdateDeliveryStatusesAtServer()
	
	For Each Recipient In Object.Participants Do
		
		DeliveryStatus = SMS.DeliveryStatus(Recipient.MessageID);
		Recipient.DeliveryStatus = DriveInteractions.MapSMSDeliveryStatus(DeliveryStatus);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RecipientsContactSelectionEnd(AddressInStorage, AdditionalParameters) Export
	
	If IsTempStorageURL(AddressInStorage) Then
		
		LockFormDataForEdit();
		Modified = True;
		FillContactsByAddressBook(AddressInStorage)
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillContactsByAddressBook(AddressInStorage)
	
	RecipientsTable = GetFromTempStorage(AddressInStorage);
	CurrentRowDataProcessor = True;
	For Each SelectedRow In RecipientsTable Do
		
		If CurrentRowDataProcessor Then
			RowParticipants = Object.Participants.FindByID(Items.Recipients.CurrentRow);
			CurrentRowDataProcessor = False;
		Else
			RowParticipants = Object.Participants.Add();
		EndIf;
		
		RowParticipants.Contact = SelectedRow.Contact;
		RowParticipants.HowToContact = SelectedRow.HowToContact;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForAutomaticSelection

// Procedure fills contact selection data.
//
// Parameters:
//  SearchString - String	 - Text being typed
&AtServerNoContext
Function GetContactChoiceList(val SearchString)
	
	ContactSelectionData = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	
	CounterpartySelectionData = Catalogs.Counterparties.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In CounterpartySelectionData Do
		ContactSelectionData.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (counterparty)"));
	EndDo;
	
	ContactPersonSelectionData = Catalogs.ContactPersons.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In ContactPersonSelectionData Do
		ContactSelectionData.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (contact person)"));
	EndDo;
	
	Return ContactSelectionData;
	
EndFunction

// Procedure fills subject selection data.
//
// Parameters:
//  SearchString - String	 - The SubjectHistoryByRow text being typed - ValueList	 - Used subjects in the row form
&AtServerNoContext
Function GetSubjectChoiceList(val SearchString, val SubjectRowHistory)
	
	ListChoiceOfTopics = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	ChoiceParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.Items);
	
	SubjectSelectionData = Catalogs.EventsSubjects.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In SubjectSelectionData Do
		ListChoiceOfTopics.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (event subject)"));
	EndDo;
	
	For Each HistoryItem In SubjectRowHistory Do
		If Left(HistoryItem.Value, StrLen(SearchString)) = SearchString Then
			ListChoiceOfTopics.Add(HistoryItem.Value, 
				New FormattedString(New FormattedString(SearchString,New Font(,,True),WebColors.Green), Mid(HistoryItem.Value, StrLen(SearchString)+1)));
		EndIf;
	EndDo;
	
	Return ListChoiceOfTopics;
	
EndFunction

// Procedure imports the event subject automatic selection history.
//
&AtServer
Procedure ImportSubjectHistoryByString()
	
	ListChoiceOfTopics = Common.CommonSettingsStorageLoad("ThemeEventsChoiceList", "");
	If ListChoiceOfTopics <> Undefined Then
		SubjectRowHistory.LoadValues(ListChoiceOfTopics);
	EndIf;
	
EndProcedure

#EndRegion

#Region SecondaryDataFilling

// Procedure fills the event content from the subject template.
//
&AtClient
Procedure FillContentEvents(EventSubject)
	
	If TypeOf(EventSubject) <> Type("CatalogRef.EventsSubjects") Then
		Return;
	EndIf;
	
	If Not IsBlankString(Object.Content) Then
		
		ShowQueryBox(New NotifyDescription("FillEventContentEnd", ThisObject, New Structure("EventSubject", EventSubject)),
			NStr("en = 'Refill the content by the selected topic?'; ru = 'Перезаполнить содержание по выбранной теме?';pl = 'Wypełnić ponownie zawartość według wybranego tematu?';es_ES = '¿Volver a rellenar el contenido por el tema seleccionado?';es_CO = '¿Volver a rellenar el contenido por el tema seleccionado?';tr = 'İçerik seçilen konuya göre doldurulsun mu?';it = 'Ricarica il contenuto per l''argomento selezionato?';de = 'Den Inhalt mit dem ausgewählten Thema erneut ausfüllen?'"), QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillEventContentFragment(EventSubject);
	
EndProcedure

&AtClient
Procedure FillEventContentEnd(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	FillEventContentFragment(AdditionalParameters.EventSubject);
	
EndProcedure

&AtClient
Procedure FillEventContentFragment(Val EventSubject)
	
	Object.Content = GetContentSubject(EventSubject);
	
EndProcedure

// Function returns the content by selected subject.
//
&AtServerNoContext
Function GetContentSubject(EventSubject)
	
	Return EventSubject.Content;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)

PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);

EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()

PropertyManager.UpdateAdditionalAttributesItems(ThisObject);

EndProcedure

// End StandardSubsystems.Properties

#EndRegion

