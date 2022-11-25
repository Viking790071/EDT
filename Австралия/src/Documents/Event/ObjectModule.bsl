#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, "FillingHandler");
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	FillAttributeParticipantsList();
	FillPresentation();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If EventType = Enums.EventTypes.Email
		AND IncomingOutgoingEvent = Enums.IncomingOutgoingEvent.Incoming Then
		Raise NStr("en = 'You can not copy an incoming message.'; ru = 'Копирование входящего письма невозможно.';pl = 'Kopiowanie wiadomości wchodzącej nie jest możliwe.';es_ES = 'Usted no puede copiar un mensaje entrante.';es_CO = 'Usted no puede copiar un mensaje entrante.';tr = 'Gelen mesaj kopyalanamaz.';it = 'Non è possibile copiare un messaggio in arrivo.';de = 'Sie können eine eingehende Nachricht nicht kopieren.'");
	EndIf;
	
	If EventType = Enums.EventTypes.Email Or EventType = Enums.EventTypes.SMS Then
		EventBegin	= '00010101';
		EventEnding	= '00010101';
	Else
		EventBegin = CurrentSessionDate();
		EventBegin = BegOfHour(EventBegin) + ?(Minute(EventBegin) < 30, 1800, 3600);
		EventEnding = EventBegin + 1800;
	EndIf;
	
	State = Catalogs.JobAndEventStatuses.Planned;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If EventEnding < EventBegin Then
		CommonClientServer.MessageToUser(
			NStr("en = 'The end date cannot be earlier than the start date.'; ru = 'Дата окончания интервала не может быть меньше даты начала.';pl = 'Data zakończenia nie może być wcześniejsza od daty rozpoczęcia.';es_ES = 'La fecha del fin no puede ser anterior a la fecha del inicio.';es_CO = 'La fecha del fin no puede ser anterior a la fecha del inicio.';tr = 'Bitiş tarihi, başlangıç tarihinden önce olamaz.';it = 'La data di fine non può essere anteriore alla data di inizio.';de = 'Das Enddatum darf nicht vor dem Startdatum liegen.'"),
			ThisObject,
			"EventEnding",
			,
			Cancel
		);
	EndIf;
	
	// For the form of other events its own table of contacts is implemented
	If Not (EventType = Enums.EventTypes.Email Or EventType = Enums.EventTypes.SMS) Then
		CheckedAttributes.Delete(CheckedAttributes.Find("Participants.Contact"));
	EndIf;
	
	If EventType = Enums.EventTypes.Email Or EventType = Enums.EventTypes.SMS Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Subject");
	EndIf;
	
EndProcedure

#EndRegion

#Region Interface
	
Procedure FillAttributeParticipantsList() Export
	
	ParticipantsList = "";
	For Each Participant In Participants Do
		ParticipantsList = ParticipantsList + ?(ParticipantsList = "","","; ")
			+ Participant.Contact + ?(IsBlankString(Participant.HowToContact), "", " <" + Participant.HowToContact + ">");
	EndDo;
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillingHandler(FillingData) Export
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	If Not FillingData.Property("EventType") Then
		Return;
	EndIf;
	
	EventType = FillingData.EventType;
	
	If EventType <> Enums.EventTypes.Email
		AND EventType <> Enums.EventTypes.SMS Then
		
		If Not ValueIsFilled(EventBegin) Or Not ValueIsFilled(EventEnding) Then
			If FillingData.Property("EventBegin") Then
				EventBegin = FillingData.EventBegin;
			Else
				EventBegin = CurrentSessionDate();
			EndIf;
			If FillingData.Property("EventEnding") Then
				EventEnding = FillingData.EventEnding;
			Else
				EventEnding = EventBegin + 1800;
			EndIf;
		EndIf;
		
		If FillingData.Property("Lead") And TypeOf(FillingData.Lead) = Type("CatalogRef.Leads") Then
			FillByLead(FillingData.Lead);
		EndIf;
		
	EndIf;
	
	If FillingData.Property("Counterparty")
		AND TypeOf(FillingData.Counterparty) = Type("CatalogRef.Counterparties") Then
		FillByCounterparty(FillingData.Counterparty);
	EndIf;
	
	If FillingData.Property("Contact") Then
		
		If TypeOf(FillingData.Contact) = Type("CatalogRef.ContactPersons") Then
			ParticipantsRow = Participants.Add();
			ParticipantsRow.Contact = Common.ObjectAttributeValue(FillingData.Contact, "Owner");
		EndIf;
		
		ParticipantsRow = Participants.Add();
		ParticipantsRow.Contact = FillingData.Contact;
		
		If FillingData.Property("ValueCI") Then
			ParticipantsRow.HowToContact = FillingData.ValueCI;
		EndIf;
		
	EndIf;
	
	If FillingData.EventType = Enums.EventTypes.PhoneCall
		AND FillingData.Property("PhoneNumber") Then
		
		Content = StrTemplate(NStr("en = 'Call from number:%1.'; ru = 'Звонок с номера: %1.';pl = 'Połączenie z numeru:%1.';es_ES = 'Llamada del número:%1.';es_CO = 'Llamada del número:%1.';tr = 'Aşağıdaki numaradan çağrı: %1';it = 'Chiamata a partire dal numero:%1.';de = 'Aufruf von der Nummer: %1.'"), FillingData.PhoneNumber);
	EndIf;
	
	If Not FillingData.Property("FillingBasis") Then
		// Create a new event without basis
		FillByDefault();
		Return;
	EndIf;
	
	If TypeOf(FillingData.FillingBasis) = Type("CatalogRef.Counterparties") Then
		
		FillByCounterparty(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("CatalogRef.Leads") Then
		
		FillByLead(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("CatalogRef.ContactPersons") Then
		
		FillByContactPerson(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.Event") Then
		
		FillByEvent(FillingData);
		
	// begin Drive.FullVersion
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.EmployeeTask") Then
		
		FillByEmployeeTask(FillingData.FillingBasis);
		
	// end Drive.FullVersion
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.SalesOrder") Then
		
		FillBySalesOrder(FillingData.FillingBasis);
		
	// begin Drive.FullVersion	
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.ProductionOrder") Then
		
		FillByProductionOrder(FillingData.FillingBasis);
		
	// end Drive.FullVersion
	
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.ReconciliationStatement") Then
		
		FillByReconciliationStatement(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("Structure") Then
		
		FillByStructure(FillingData.FillingBasis);
		
	ElsIf AvailableTypeForGeneratingOnBase(FillingData.FillingBasis) Then
		
		BasisDocuments.Clear();
		If EventType = Enums.EventTypes.Email Then
			BasisDocumentsRow = BasisDocuments.Add();
			BasisDocumentsRow.BasisDocument = FillingData.FillingBasis;
		Else
			BasisDocument = FillingData.FillingBasis;
		EndIf;
		
		Participants.Clear();
		ParticipantsRow = Participants.Add();
		ParticipantsRow.Contact = FillingData.FillingBasis.Counterparty;
		FillHowToContact();
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure FillByStructure(FillingBasis)
	
	FillPropertyValues(ThisObject, FillingBasis);
	
	// begin Drive.FullVersion
	If FillingBasis.Property("Basis")
		AND TypeOf(FillingBasis.Basis)= Type("DocumentRef.EmployeeTask") Then
		
		FillByCurrentRowEmployeeTask(FillingBasis);
		Return;
		
	EndIf;
	// end Drive.FullVersion
	
	If FillingBasis.Property("BasisDocument")
		AND AvailableTypeForGeneratingOnBase(FillingBasis.BasisDocument) Then
		
		BasisDocuments.Clear();
		If EventType = Enums.EventTypes.Email Then
			BasisDocumentsRow = BasisDocuments.Add();
			BasisDocumentsRow.BasisDocument = FillingBasis.BasisDocument;
		Else
			BasisDocument = FillingBasis.BasisDocument;
		EndIf;
		
	EndIf;
	
	If FillingBasis.Property("Contact") AND ValueIsFilled(FillingBasis.Contact) Then
		
		Participants.Clear();
		
		If TypeOf(FillingBasis.Contact) = Type("CatalogRef.ContactPersons") Then
			ParticipantsRow = Participants.Add();
			ParticipantsRow.Contact = FillingBasis.Contact.Owner;
		EndIf;
		
		ParticipantsRow = Participants.Add();
		ParticipantsRow.Contact = FillingBasis.Contact;
		
		FillHowToContact();
		
	EndIf;
	
EndProcedure

Procedure FillByCounterparty(Counterparty)
	
	If Counterparty.IsFolder Then
		Raise NStr("en = 'You cannot select a counterparty group.'; ru = 'Нельзя выбирать группу контрагентов.';pl = 'Wybór grupy kontrahentów nie jest możliwy.';es_ES = 'Usted no puede seleccionar un grupo de contrapartes.';es_CO = 'Usted no puede seleccionar un grupo de contrapartes.';tr = 'Cari hesap grubu seçilemez.';it = 'Non è possibile selezionare un gruppo di controparte.';de = 'Sie können keine Geschäftspartnergruppe auswählen.'");
	EndIf;
	
	Participants.Clear();
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	ContactPersons.Ref
		|FROM
		|	Catalog.ContactPersons AS ContactPersons
		|WHERE
		|	ContactPersons.Owner = &Owner
		|	AND ContactPersons.DeletionMark = FALSE
		|
		|ORDER BY
		|	ContactPersons.Description";
	
	Query.SetParameter("Owner", Counterparty);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ParticipantsRow	= Participants.Add();
		ParticipantsRow.Contact	= Selection.Ref;
	EndDo;
	
	RowParticipants = Participants.Insert(0);
	RowParticipants.Contact = Counterparty;
	FillHowToContact();
	
EndProcedure

Procedure FillByLead(Lead)
	
	Participants.Clear();
	
	TypesCI = New Array;
	
	If NOT EventType = Enums.EventTypes.SMS AND NOT EventType = Enums.EventTypes.PhoneCall Then
		TypesCI.Add(Enums.ContactInformationTypes.EmailAddress);
	EndIf;
	
	If NOT EventType = Enums.EventTypes.Email Then
		TypesCI.Add(Enums.ContactInformationTypes.Phone);
	EndIf;

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	CASE
	|		WHEN LeadsContactInformation.Type = VALUE(Enum.ContactInformationTypes.Phone)
	|			THEN 1
	|		ELSE 2
	|	END AS Order,
	|	LeadsContactInformation.Presentation AS Presentation,
	|	CAST(LeadsContacts.Representation AS STRING(1024)) AS Contact
	|FROM
	|	Catalog.Leads.ContactInformation AS LeadsContactInformation
	|		INNER JOIN Catalog.Leads.Contacts AS LeadsContacts
	|		ON LeadsContactInformation.ContactLineIdentifier = LeadsContacts.ContactLineIdentifier
	|			AND LeadsContactInformation.Ref = LeadsContacts.Ref
	|WHERE
	|	LeadsContactInformation.Ref = &Lead
	|	AND LeadsContactInformation.Type IN(&TypesCI)
	|
	|ORDER BY
	|	Order,
	|	LeadsContactInformation.LineNumber
	|TOTALS BY
	|	Contact";
	
	Query.SetParameter("Lead", Lead);
	Query.SetParameter("TypesCI", TypesCI);
	
	QueryResults = Query.Execute();
	
	FirstRow = True;
	
	Selection = QueryResults.Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do
		
		HowToContact = "";
		
		HowToContactSelection = Selection.Select();
		While HowToContactSelection.Next() Do
			HowToContact = HowToContact + ?(HowToContact = "", "", ", ") + HowToContactSelection.Presentation;
		EndDo;
		
		If FirstRow Then
			
			RowParticipants = Participants.Add();
			RowParticipants.Contact = Lead;
			
			FirstRow = False
			
		EndIf;
		
		RowParticipants = Participants.Add();
		RowParticipants.Contact = Selection.Contact;
		RowParticipants.HowToContact = HowToContact;
		
	EndDo;
	
EndProcedure

Procedure FillByContactPerson(ContactPerson)
	
	Participants.Clear();
	
	TypesCI = New Array;
	If Not EventType = Enums.EventTypes.SMS Then
		TypesCI.Add(Enums.ContactInformationTypes.EmailAddress);
	EndIf;
	If Not EventType = Enums.EventTypes.Email Then
		TypesCI.Add(Enums.ContactInformationTypes.Phone);
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	CASE
		|		WHEN CounterpartiesContactInformation.Type = VALUE(Enum.ContactInformationTypes.Phone)
		|			THEN 1
		|		ELSE 2
		|	END AS Order,
		|	CounterpartiesContactInformation.Presentation
		|FROM
		|	Catalog.Counterparties.ContactInformation AS CounterpartiesContactInformation
		|WHERE
		|	CounterpartiesContactInformation.Ref = &Counterparty
		|	AND CounterpartiesContactInformation.Type IN(&TypesCI)
		|
		|ORDER BY
		|	Order,
		|	CounterpartiesContactInformation.LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	CASE
		|		WHEN ContactPersonsContactInformation.Type = VALUE(Enum.ContactInformationTypes.Phone)
		|			THEN 1
		|		ELSE 2
		|	END AS Order,
		|	ContactPersonsContactInformation.Presentation
		|FROM
		|	Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
		|WHERE
		|	ContactPersonsContactInformation.Ref = &ContactPerson
		|	AND ContactPersonsContactInformation.Type IN(&TypesCI)
		|
		|ORDER BY
		|	Order,
		|	ContactPersonsContactInformation.LineNumber";
	
	Query.SetParameter("Counterparty", ContactPerson.Owner);
	Query.SetParameter("ContactPerson", ContactPerson);
	Query.SetParameter("TypesCI", TypesCI);
	
	ResultsArray = Query.ExecuteBatch();
	
	Selection = ResultsArray[0].Select();
	HowToContact = "";
	
	While Selection.Next() Do
		HowToContact = HowToContact + ?(HowToContact = "", "", ", ") + Selection.Presentation;
	EndDo;
	
	RowParticipants = Participants.Add();
	RowParticipants.Contact = ContactPerson.Owner;
	RowParticipants.HowToContact = HowToContact;
	
	Selection = ResultsArray[1].Select();
	HowToContact = "";
	
	While Selection.Next() Do
		HowToContact = HowToContact + ?(HowToContact = "", "", ", ") + Selection.Presentation;
	EndDo;
	
	RowParticipants = Participants.Add();
	RowParticipants.Contact = ContactPerson;
	RowParticipants.HowToContact = HowToContact;
	
EndProcedure

Procedure FillByEvent(FillingData)
	
	Participants.Clear();
	
	// Filling participants
	If CommonClientServer.StructureProperty(
		FillingData,
		"Command",
		EmailDriveClientServer.CommandReply()) = EmailDriveClientServer.CommandReply() Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	EventParticipants.Contact AS Contact,
		|	EventParticipants.HowToContact AS HowToContact
		|FROM
		|	Document.Event.Participants AS EventParticipants
		|WHERE
		|	EventParticipants.Ref = &Ref
		|
		|ORDER BY
		|	EventParticipants.LineNumber");
		
		Query.SetParameter("Ref", FillingData.FillingBasis);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			ParticipantsRow = Participants.Add();
			ParticipantsRow.Contact			= Selection.Contact;
			ParticipantsRow.HowToContact	= Selection.HowToContact;
		EndDo;
		
	EndIf;
		
	// Filling of basis documents
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		BasisDocumentsRow = BasisDocuments.Add();
		BasisDocumentsRow.BasisDocument = FillingData.FillingBasis;
		FillEmailSubject(FillingData);
	Else
		BasisDocument = FillingData.FillingBasis;
	EndIf;
	
	UserAccount = Common.ObjectAttributeValue(FillingData.FillingBasis, "UserAccount");
	
EndProcedure

Procedure FillByReconciliationStatement(FillingData)
	
	IncomingOutgoingEvent = Enums.IncomingOutgoingEvent.Outgoing;
	BasisDocument = FillingData.Ref;
	Counterparty = FillingData.Counterparty;
	
	Participants.Clear();
	If ValueIsFilled(BasisDocument.CounterpartyRepresentative) Then
		
		ContactPerson = BasisDocument.CounterpartyRepresentative;
		
		NewRow = Participants.Add();
		NewRow.Contact = ContactPerson;
		
		HowToContactPhone = ContactsManager.ObjectContactInformation(ContactPerson, Catalogs.ContactInformationKinds.ContactPersonPhone);
		HowToContactEmail = ContactsManager.ObjectContactInformation(ContactPerson, Catalogs.ContactInformationKinds.ContactPersonEmail);
		
		If IsBlankString(HowToContactPhone) Then
			NewRow.HowToContact = TrimAll(HowToContactEmail);
		ElsIf IsBlankString(HowToContactEmail) Then
			NewRow.HowToContact = TrimAll(HowToContactPhone);
		Else
			NewRow.HowToContact = TrimAll(HowToContactPhone) + "; " + TrimAll(HowToContactEmail);
		EndIf;
		
	EndIf;
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = BasisDocument;
	EndIf;
	
EndProcedure

// begin Drive.FullVersion
Procedure FillByEmployeeTask(EmployeeTask)
	
	Participants.Clear();
	
	// Filling out a document header.
	Query = New Query;
	Query.SetParameter("Ref", EmployeeTask);
	
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	CASE
	|		WHEN VALUETYPE(Works.Customer) = TYPE(Catalog.Counterparties)
	|			THEN Works.Customer
	|		WHEN VALUETYPE(Works.Customer) = TYPE(Catalog.CounterpartyContracts)
	|			THEN Works.Customer.Owner
	|		WHEN VALUETYPE(Works.Customer) = TYPE(Document.SalesOrder)
	|			THEN Works.Customer.Counterparty
	|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
	|	END AS Counterparty,
	|	Works.BeginTime AS EventBegin,
	|	Works.EndTime AS EventEnding,
	|	Works.Day AS Day
	|FROM
	|	Document.EmployeeTask.Works AS Works
	|WHERE
	|	Works.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		If ValueIsFilled(Selection.Counterparty) Then
			ParticipantsRow = Participants.Add();
			ParticipantsRow.Contact = Selection.Counterparty;
			FillHowToContact();
		EndIf;
		
	EndIf;
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = EmployeeTask;
	Else
		BasisDocument = EmployeeTask;
	EndIf;
	
EndProcedure
// end Drive.FullVersion

Procedure FillBySalesOrder(SalesOrder)
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = SalesOrder;
	Else
		BasisDocument = SalesOrder;
	EndIf;
	Project = SalesOrder.Project;
	
	Participants.Clear();
	RowParticipants = Participants.Add();
	RowParticipants.Contact = SalesOrder.Counterparty;
	FillHowToContact();
	
EndProcedure

// begin Drive.FullVersion
Procedure FillByProductionOrder(ProductionOrder)
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		BasisDocumentsRow = BasisDocuments.Add();
		BasisDocumentsRow.BasisDocument = ProductionOrder;
	Else
		BasisDocument = ProductionOrder;
	EndIf;
	
	If EventType <> Enums.EventTypes.Email
		И EventType <> Enums.EventTypes.SMS Then
		
		EventBegin	= ProductionOrder.Start;
		EventEnding	= ProductionOrder.Finish;
	EndIf;
	
EndProcedure
// end Drive.FullVersion

// begin Drive.FullVersion
Procedure FillByCurrentRowEmployeeTask(FillingStructure)
	
	Participants.Clear();
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = FillingStructure.Basis;
	Else
		BasisDocument = FillingStructure.Basis;
	EndIf;
	
	If TypeOf(FillingStructure.Customer) = Type("CatalogRef.Counterparties") Then
		RowParticipants = Participants.Add();
		RowParticipants.Contact = FillingStructure.Customer;
	ElsIf TypeOf(FillingStructure.Customer) = Type("CatalogRef.CounterpartyContracts") Then
		RowParticipants = Participants.Add();
		RowParticipants.Contact = FillingStructure.Customer.Owner;
	ElsIf TypeOf(FillingStructure.Customer) = Type("DocumentRef.SalesOrder") Then
		RowParticipants = Participants.Add();
		RowParticipants.Contact = FillingStructure.Customer.Counterparty;
	EndIf;
	
	If RowParticipants <> Undefined AND ValueIsFilled(RowParticipants.Contact) Then
		FillHowToContact();
	EndIf;
	
	EventBegin	= FillingStructure.EventBegin;
	EventEnding	= FillingStructure.EventEnding;
	
	Responsible = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	
EndProcedure
// end Drive.FullVersion

Procedure FillHowToContact()
	
	Counterparties = Participants.UnloadColumn("Contact");
	CommonClientServer.DeleteAllTypeOccurrencesFromArray(Counterparties, Type("String"));
	ContactPersons = CommonClientServer.CopyArray(Counterparties);
	CommonClientServer.DeleteAllTypeOccurrencesFromArray(Counterparties, Type("CatalogRef.ContactPersons"));
	CommonClientServer.DeleteAllTypeOccurrencesFromArray(ContactPersons, Type("CatalogRef.Counterparties"));
	
	TypesCI = New Array;
	If Not EventType = Enums.EventTypes.SMS AND Not EventType = Enums.EventTypes.PhoneCall Then
		TypesCI.Add(Enums.ContactInformationTypes.EmailAddress);
	EndIf;
	If Not EventType = Enums.EventTypes.Email Then
		TypesCI.Add(Enums.ContactInformationTypes.Phone);
	EndIf;
	
	If Counterparties.Count() > 0 Then
		TableCI_Counterparties = ContactsManager.ObjectsContactInformation(Counterparties, TypesCI);
		TableCI_Counterparties.Sort("Object Asc, Type Desc");
	EndIf;
	
	If ContactPersons.Count() > 0 Then
		TableCI_ContactPersons = ContactsManager.ObjectsContactInformation(ContactPersons, TypesCI);
		TableCI_ContactPersons.Sort("Object Asc, Type Desc");
	EndIf;
	
	Filter = New Structure("Object");
	Index = 0;
	
	While Index <= Participants.Count()-1 Do
		
		CurRow = Participants[Index];
		Filter.Object = CurRow.Contact;
		RowsCI = New Array;
		
		If TypeOf(CurRow.Contact) = Type("CatalogRef.Counterparties") AND TableCI_Counterparties <> Undefined AND TableCI_Counterparties.Count() > 0 Then
			RowsCI = TableCI_Counterparties.FindRows(Filter);
		ElsIf TypeOf(CurRow.Contact) = Type("CatalogRef.ContactPersons") AND TableCI_ContactPersons <> Undefined AND TableCI_ContactPersons.Count() > 0 Then
			RowsCI = TableCI_ContactPersons.FindRows(Filter);
		EndIf;
		
		// For SMS, each phone on a new line
		// For other types of events, we display the contact information in one line
		
		If EventType = Enums.EventTypes.SMS Then
			FirstValueCI = True;
			For Each RowCI In RowsCI Do
				If Not FirstValueCI Then
					Index = Index + 1;
					CurRow = Participants.Insert(Index);
					CurRow.Contact = Filter.Object;
				EndIf;
				CurRow.HowToContact = RowCI.Presentation;
				FirstValueCI = False;
			EndDo;
		Else
			For Each RowCI In RowsCI Do
				CurRow.HowToContact = "" + CurRow.HowToContact + ?(CurRow.HowToContact = "", "", ", ") + RowCI.Presentation;
			EndDo;
		EndIf;
		
		Index = Index + 1;
		
	EndDo;
	
EndProcedure

Function AvailableTypeForGeneratingOnBase(DocBasis)
	
	Return Common.HasObjectAttribute(
	"Counterparty",
	DocBasis.Metadata());
	
EndFunction

#EndRegion

#Region InterfaceEmployeeCalendar

Procedure FillByDefault()
	
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctionsEmail

Procedure FillEmailSubject(FillingData)
	
	EventAttributesValues = Common.ObjectAttributesValues(FillingData.FillingBasis, "Subject, IncomingOutgoingEvent");
	If EventAttributesValues.IncomingOutgoingEvent <> Enums.IncomingOutgoingEvent.Incoming Then
		Return;
	EndIf;
	
	Subject = Documents.Event.SubjectWithResponsePrefix(
	EventAttributesValues.Subject,
	CommonClientServer.StructureProperty(
	FillingData,
	"Command",
	EmailDriveClientServer.CommandReply()));

EndProcedure

Procedure FillPresentation()
	
	
EndProcedure

#EndRegion

#EndIf