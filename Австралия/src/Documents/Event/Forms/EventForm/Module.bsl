
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.ContactsContact.TypeRestriction	= New TypeDescription("String",, New StringQualifiers(100));
	Items.Subject.TypeRestriction			= New TypeDescription("String",, New StringQualifiers(200));
	
	If Not ValueIsFilled(Object.Ref) Then
		ReadAttributes(Object);
		AutoTitle = False;
		Title = StrTemplate(
		NStr("en = 'Event: %1 (Create)'; ru = 'Событие: %1 (создание)';pl = 'Wydarzenie: %1 (Utworzenie)';es_ES = 'Evento: %1 (creación)';es_CO = 'Evento: %1 (creación)';tr = 'Etkinlik: %1 (Oluştur)';it = 'Evento: %1 (Crea)';de = 'Ereignis: %1 (Erstellen)'"),
		Object.EventType);
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	NotifyWorkCalendar = False;
	
	EventsDriveClientServer.FillTimeChoiceList(Items.EventBeginTime);
	EventsDriveClientServer.FillTimeChoiceList(Items.EventEndTime);
	
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

&AtClient
Procedure OnClose(Exit)
	
	If NotifyWorkCalendar Then
		Notify("EventChanged", Object.Responsible);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NewWriteProcessing(NewObject, Source, StandardProcessing)
	
	If TypeOf(NewObject) = Type("CatalogRef.ContactPersons") Then
		
		ContactPersonParameters = GetContactPersonParameters(NewObject);
		If ContactPersonParameters.Owner <> Counterparty Then
			Return;
		EndIf;
		
		RowContacts = Contacts.Add();
		RowContacts.Contact = NewObject;
		RowContacts.HowToContact = ContactPersonParameters.HowToContact;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	ReadAttributes(CurrentObject);
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		NotifyWorkCalendar = True;
	EndIf;
	
	WriteAttributes(CurrentObject);
	
	If TypeOf(CurrentObject.Subject) = Type("String") Then
	// Save subjects in history for automatic selection
		
		HistoryItem = SubjectRowHistory.FindByValue(TrimAll(CurrentObject.Subject));
		If HistoryItem <> Undefined Then
			SubjectRowHistory.Delete(HistoryItem);
		EndIf;
		SubjectRowHistory.Insert(0, TrimAll(CurrentObject.Subject));
		
		Common.CommonSettingsStorageSave("ThemeEventsChoiceList", "", SubjectRowHistory.UnloadValues());
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Title = "";
	AutoTitle = True;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	For Each RowContacts In Contacts Do
		If Not ValueIsFilled(RowContacts.Contact) Then
			CommonClientServer.MessageToUser(
				CommonClientServer.FillingErrorText("Column", "Filling", "Contact", Contacts.IndexOf(RowContacts) + 1, "Participants"),
				,
				StringFunctionsClientServer.SubstituteParametersToString("Contacts[%1].Contact", Contacts.IndexOf(RowContacts)),
				,
				Cancel
			);
		EndIf;
	EndDo;
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties

EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure EventBeginTimeOnChange(Item)
	
	FormDurationPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure EventBeginTimeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	SelectedValue = BegOfDay(Object.EventBegin) + (SelectedValue - BegOfDay(SelectedValue));
	
EndProcedure

&AtClient
Procedure EventBeginDateOnChange(Item)
	
	FormDurationPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure EventEndTimeOnChange(Item)
	
	FormDurationPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure EventEndTimeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	SelectedValue = BegOfDay(Object.EventEnding) + (SelectedValue - BegOfDay(SelectedValue));
	
EndProcedure

&AtClient
Procedure EventEndDateOnChange(Item)
	
	FormDurationPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyOnChangeServer();
	
EndProcedure

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

&AtClient
Procedure ContactsContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not ValueIsFilled(Counterparty) Then
		CommonClientServer.MessageToUser(NStr("en = 'Select a counterparty.'; ru = 'Необходимо выбрать контрагента.';pl = 'Wybór kontrahenta.';es_ES = 'Seleccionar una contraparte.';es_CO = 'Seleccionar una contraparte.';tr = 'Cari hesabı seç.';it = 'Selezionare una controparte.';de = 'Wählen Sie einen Geschäftspartner aus.'"), , "Counterparty");
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("Owner",Counterparty));
	FormParameters.Insert("CurrentRow", Items.Contacts.CurrentData.Contact);
	FormParameters.Insert("ChoiceMode", True);
	
	OpenForm("Catalog.ContactPersons.ChoiceForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure ContactsContactOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Items.Contacts.CurrentData.Contact) Then
		Contact = Contacts.FindByID(Items.Contacts.CurrentRow).Contact;
		ShowValue(,Contact);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactsContactChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If ValueIsFilled(ValueSelected) Then
		HowToContact = GetHowToContact(ValueSelected, False);
	EndIf;
	
	RowContacts = Contacts.FindByID(Items.Contacts.CurrentRow);
	RowContacts.Contact = ValueSelected;
	RowContacts.HowToContact = HowToContact;
	
EndProcedure

&AtClient
Procedure ContactsContactAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) AND ValueIsFilled(Counterparty) Then
		StandardProcessing = False;
		ChoiceData = GetContactChoiceList(Text, Counterparty);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a base document.'; ru = 'Не выбран документ-основание.';pl = 'Wybierz dokument źródłowy.';es_ES = 'Por favor, seleccione un documento de base.';es_CO = 'Por favor, seleccione un documento de base.';tr = 'Lütfen, temel belge seçin.';it = 'Si prega di selezionare un documento di base.';de = 'Bitte wählen Sie ein Basisdokument aus.'"));
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the event?'; ru = 'Документ будет полностью перезаполнен по ""Основанию"". Продолжить?';pl = 'Czy chcesz uzupełnić wydarzenie?';es_ES = '¿Quiere volver a rellenar el evento?';es_CO = '¿Quiere volver a rellenar el evento?';tr = 'Etkinliği yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare l''evento?';de = 'Möchten Sie das Ereignis nachfüllen?'"), QuestionDialogMode.YesNo, 0);
		
EndProcedure

&AtClient
Procedure FillContent(Command)
	
	If ValueIsFilled(Object.Subject) Then
		FillContentEvents(Object.Subject);
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByCounterparty(Command)
	
	If Contacts.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("FillByCounterpartyEnd", ThisObject),
			NStr("en = 'Contacts will be completely refilled according to the counterparty. Continue?'; ru = 'Контакты будут полностью перезаполнены по контрагенту! Продолжить?';pl = 'Kontakty będą całkowicie zamienione zgodnie z kontrahentem. Kontynuować?';es_ES = 'Contactos se volverán a rellenar según la contraparte. ¿Continuar?';es_CO = 'Contactos se volverán a rellenar según la contraparte. ¿Continuar?';tr = 'İlgili Kişiler cari hesaba göre tamamen doldurulacak. Devam et?';it = 'I contatti saranno completamente riempiti dalla controparte! Continuare?';de = 'Die Kontakte werden entsprechend dem Geschäftspartner vollständig nachgefüllt. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
	Else
		FillByCounterpartyFragment(DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateContact(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Owner", Counterparty);
	
	OpenForm("Catalog.ContactPersons.ObjectForm", New Structure("Basis", OpenParameters), ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ReadAttributes(Object)
	
	Contacts.Clear();
	FirstRow = True;
	
	For Each RowParticipants In Object.Participants Do
		
		If FirstRow Then
			Counterparty				= RowParticipants.Contact;
			CounterpartyHowToContact	= RowParticipants.HowToContact;
			FirstRow = False;
			Continue;
		EndIf;
		
		RowContacts = Contacts.Add();
		FillPropertyValues(RowContacts, RowParticipants);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteAttributes(Object)
	
	Object.Participants.Clear();
	
	RowParticipants = Object.Participants.Add();
	RowParticipants.Contact = Counterparty;
	RowParticipants.HowToContact = CounterpartyHowToContact;
	
	For Each RowContacts In Contacts Do
		FillPropertyValues(Object.Participants.Add(), RowContacts);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetContactPersonParameters(ContactPerson)
	
	Result = New Structure;
	Result.Insert("Owner", ContactPerson.Owner);
	Result.Insert("HowToContact", GetHowToContact(ContactPerson, False));
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetHowToContact(Contact, IsEmail = False)
	
	If TypeOf(Contact) = Type("CatalogRef.Leads") Then
		Return "";
	Else
		Return Documents.Event.GetHowToContact(Contact, IsEmail);
	EndIf;
	
EndFunction

&AtServer
Procedure CounterpartyOnChangeServer()
	
	CounterpartyHowToContact = GetHowToContact(Counterparty, False);
	
	// Clear contact person other counterparties
	For Each RowContacts In Contacts Do
		If TypeOf(RowContacts.Contact) = Type("CatalogRef.ContactPersons") AND RowContacts.Contact.Owner <> Counterparty Then
			RowContacts.Contact = Catalogs.ContactPersons.EmptyRef();
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure ImportSubjectHistoryByString()
	
	ListChoiceOfTopics = Common.CommonSettingsStorageLoad("ThemeEventsChoiceList", "");
	If ListChoiceOfTopics <> Undefined Then
		SubjectRowHistory.LoadValues(ListChoiceOfTopics);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetSubjectChoiceList(val SearchString, val SubjectRowHistory)
	
	ListChoiceOfTopics = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	ChoiceParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.Items);
	
	SubjectSelectionData = Catalogs.EventsSubjects.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In SubjectSelectionData Do
		TextString = " (" + NStr("en = 'event subject'; ru = 'тема события';pl = 'temat wydarzenia';es_ES = 'tema del evento';es_CO = 'tema del evento';tr = 'etkinlik konusu';it = 'soggetto evento';de = 'Ereignisthema'") + ")";
		ListChoiceOfTopics.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, TextString));
	EndDo;
	
	For Each HistoryItem In SubjectRowHistory Do
		If Left(HistoryItem.Value, StrLen(SearchString)) = SearchString Then
			ListChoiceOfTopics.Add(HistoryItem.Value, 
				New FormattedString(New FormattedString(SearchString,New Font(,,True),WebColors.Green), Mid(HistoryItem.Value, StrLen(SearchString)+1)));
		EndIf;
	EndDo;
	
	Return ListChoiceOfTopics;
	
EndFunction

&AtServerNoContext
Function GetContactChoiceList(val SearchString, Counterparty)
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("Owner, DeletionMark", Counterparty, False));
	ChoiceParameters.Insert("SearchString", SearchString);
	
	ContactPersonSelectionData = Catalogs.ContactPersons.GetChoiceData(ChoiceParameters);
	
	Return ContactPersonSelectionData;
	
EndFunction

#EndRegion

#Region SecondaryDataFilling

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

&AtServerNoContext
Function GetContentSubject(EventSubject)
	
	Return EventSubject.Content;
	
EndFunction

&AtClient
Procedure FillByCounterpartyEnd(Result, AdditionalParameters) Export
	
	FillByCounterpartyFragment(Result);
	
EndProcedure

&AtClient
Procedure FillByCounterpartyFragment(Val Response)
	
	If Response = DialogReturnCode.Yes Then
		FillByCounterpartyServer(Counterparty);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByCounterpartyServer(Counterparty)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(New Structure("FillingBasis, EventType", Counterparty, Object.EventType));
	ValueToFormAttribute(Document, "Object");
	
	ReadAttributes(Object);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByBasisServer(Object.BasisDocument);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByBasisServer(BasisDocument)
	
	DocumentObject = FormAttributeToValue("Object");
	DocumentObject.Fill(New Structure("FillingBasis, EventType, Responsible", BasisDocument, Object.EventType, Object.Responsible));
	ValueToFormAttribute(DocumentObject, "Object");
	
	ReadAttributes(DocumentObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormDurationPresentation(Form)
	
	Form.DurationPresentation = "";
	
	Begin	= Form.Object.EventBegin;
	End		= Form.Object.EventEnding;
	
	If Not ValueIsFilled(Begin)
		Or Not ValueIsFilled(End) Then
		
		Return;
	EndIf;
	
	DurationSec = End - Begin;
	
	Days = Int(DurationSec / 86400);
	CaptionDays = DriveClientServer.PluralForm(
		NStr("en = 'Day'; ru = 'День';pl = 'Dzień';es_ES = 'Día';es_CO = 'Día';tr = 'Gün';it = 'Giorno';de = 'Tag'"),
		NStr("en = 'day'; ru = 'день';pl = 'dzień';es_ES = 'día';es_CO = 'día';tr = 'Gün';it = 'giorno';de = 'Tag'"),
		NStr("en = 'days'; ru = 'дней';pl = 'dni';es_ES = 'días';es_CO = 'días';tr = 'günler';it = 'giorni';de = 'Tage'"),
		Days
	);
	
	Hours = Int((DurationSec - Days * 86400) / 3600);
	CaptionHours = DriveClientServer.PluralForm(
		NStr("en = 'hour'; ru = 'час';pl = 'godzina';es_ES = 'hora';es_CO = 'hora';tr = 'saat';it = 'ora';de = 'Stunde'"),
		NStr("en = 'hours'; ru = 'часа';pl = 'godziny';es_ES = 'horas';es_CO = 'horas';tr = 'saat';it = 'ore';de = 'stunden'"),
		NStr("en = 'hours'; ru = 'часа';pl = 'godziny';es_ES = 'horas';es_CO = 'horas';tr = 'saat';it = 'ore';de = 'stunden'"),
		Hours
	);
	
	Minutes = Int((DurationSec - Days * 86400 - Hours * 3600) / 60);
	CaptionMinutes = DriveClientServer.PluralForm(
		NStr("en = 'minute'; ru = 'минуту';pl = 'minuta';es_ES = 'minuto';es_CO = 'minuto';tr = 'dakika';it = 'minuto';de = 'Minute'"),
		NStr("en = 'minutes'; ru = 'минут';pl = 'minuty';es_ES = 'minutos';es_CO = 'minutos';tr = 'dakikalar';it = 'minuti';de = 'Minuten'"),
		NStr("en = 'minutes'; ru = 'минут';pl = 'minuty';es_ES = 'minutos';es_CO = 'minutos';tr = 'dakikalar';it = 'minuti';de = 'Minuten'"),
		Minutes
	);
	
	If Days > 0 Then
		Form.DurationPresentation = Form.DurationPresentation + String(Days) + " " + CaptionDays;
	EndIf;
	
	If Hours > 0 Then
		
		If Days > 0 Then
			Form.DurationPresentation = Form.DurationPresentation + " ";
		EndIf;
		
		Form.DurationPresentation = Form.DurationPresentation + String(Hours) + " " + CaptionHours;
	EndIf;
	
	If Minutes > 0 Then
		
		If Days > 0 Or Hours > 0 Then
			Form.DurationPresentation = Form.DurationPresentation + " ";
		EndIf;
		
		Form.DurationPresentation = Form.DurationPresentation + String(Minutes) + " " + CaptionMinutes;
	EndIf;
	
EndProcedure

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
