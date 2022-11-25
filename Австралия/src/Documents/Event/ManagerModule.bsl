#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetOperationKindMapToForms() Export

	EventForms = New Map;
	EventForms.Insert(Enums.EventTypes.Email, 			"EmailForm");
	EventForms.Insert(Enums.EventTypes.SMS,				"MessagesSMSForm");
	EventForms.Insert(Enums.EventTypes.PhoneCall,		"EventForm");
	EventForms.Insert(Enums.EventTypes.PersonalMeeting,	"EventForm");
	EventForms.Insert(Enums.EventTypes.Other,			"EventForm");
	
	Return EventForms;

EndFunction

#Region ToDoList

// StandardSubsystems.ToDoList

// See ToDoListOverridable.OnDetermineToDoListHandlers.
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.Documents.Event) Then
		Return;
	EndIf;
	
	ResponsibleStructure = DriveServer.ResponsibleStructure();
	DocumentsCount = DocumentsCount(ResponsibleStructure.List);
	DocumentsID = "Events";
	
	// Events
	ToDo				= ToDoList.Add();
	ToDo.ID				= DocumentsID;
	ToDo.HasUserTasks	= (DocumentsCount.PlannedEvents > 0);
	ToDo.Presentation	=  NStr("en = 'Events'; ru = 'События';pl = 'Wydarzenia';es_ES = 'Eventos';es_CO = 'Eventos';tr = 'Etkinlikler';it = 'Eventi';de = 'Ereignisse'");
	ToDo.Owner			= Metadata.Subsystems.CRM;
	
	// Expired
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "EventsExecutionExpired";
	ToDo.HasUserTasks	= (DocumentsCount.EventsExecutionExpired > 0);
	ToDo.Important		= True;
	ToDo.Presentation	= NStr("en = 'Expired'; ru = 'Просроченное';pl = 'Przedawnione';es_ES = 'Caducado';es_CO = 'Caducado';tr = 'Süresi bitmiş';it = 'Scaduto';de = 'Abgelaufen'");
	ToDo.Count			= DocumentsCount.EventsExecutionExpired;
	ToDo.Form			= "Document.Event.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// For today
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "EventsForToday";
	ToDo.HasUserTasks	= (DocumentsCount.EventsForToday > 0);
	ToDo.Presentation	= NStr("en = 'For today'; ru = 'На сегодня';pl = 'Na dzisiaj';es_ES = 'Para hoy';es_CO = 'Para hoy';tr = 'Bugün itibarıyla';it = 'Odierni';de = 'Für Heute'");
	ToDo.Count			= DocumentsCount.EventsForToday;
	ToDo.Form			= "Document.Event.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// Scheduled
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("Planned");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "EventsScheduled";
	ToDo.HasUserTasks	= (DocumentsCount.PlannedEvents > 0);
	ToDo.Presentation	= NStr("en = 'Scheduled'; ru = 'Регламентное';pl = 'Planowany';es_ES = 'Planificado';es_CO = 'Planificado';tr = 'Planlanmış';it = 'In programma';de = 'Geplant'");
	ToDo.Count			= DocumentsCount.PlannedEvents;
	ToDo.Form			= "Document.Event.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;

EndProcedure

// End StandardSubsystems.ToDoList

#EndRegion

#Region Email

Function SubjectWithResponsePrefix(Subject, Command) Export
	
	If Command = EmailDriveClientServer.CommandReply() Then
		
		If StrStartsWith(Upper(Subject), "RE:") Then
			Return Subject;
		EndIf;
		
		Return StrTemplate("Re: %1", Subject);
		
	ElsIf Command = EmailDriveClientServer.CommandForward() Then
		
		If StrStartsWith(Upper(Subject), "Fw:") Then
			Return Subject;
		EndIf;
		
		Return StrTemplate("Fw: %1", Subject);
		
	Else
		
		Return Subject;
		
	EndIf;
	
EndFunction
	
#EndRegion

#Region Interface

Function GetHowToContact(Contact, IsEmail = False) Export
	
	Result = "";
	
	Contacts = New Array;
	Contacts.Add(Contact);
	
	TypesCI = New Array;
	TypesCI.Add(Enums.ContactInformationTypes.EmailAddress);
	If Not IsEmail Then
		TypesCI.Add(Enums.ContactInformationTypes.Phone);
	EndIf;
	
	TableCI = ContactsManager.ObjectsContactInformation(Contacts, TypesCI);
	TableCI.Sort("Type DESC");
	For Each RowCI In TableCI Do
		Result = "" + Result + ?(Result = "", "", ", ") + RowCI.Presentation;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// StandardSubsystems.ToDoList

Function DocumentsCount(EmployeesList)
	
	Result = New Structure;
	Result.Insert("EventsExecutionExpired",	0);
	Result.Insert("EventsForToday",			0);
	Result.Insert("PlannedEvents",			0);
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	COUNT(DISTINCT CASE
		|			WHEN Events.EventEnding < &CurrentDateTimeSession
		|					AND Events.EventBegin <> DATETIME(1, 1, 1)
		|				THEN Events.Ref
		|		END) AS EventsExecutionExpired,
		|	COUNT(DISTINCT CASE
		|			WHEN Events.EventBegin <= &EndOfDayIfCurrentDateTimeSession
		|					AND Events.EventEnding >= &CurrentDateTimeSession
		|				THEN Events.Ref
		|		END) AS EventsForToday,
		|	COUNT(DISTINCT Events.Ref) AS PlannedEvents
		|FROM
		|	Document.Event AS Events
		|WHERE
		|	Events.State <> VALUE(Catalog.JobAndEventStatuses.Completed)
		|	AND Events.State <> VALUE(Catalog.JobAndEventStatuses.Canceled)
		|	AND Events.Responsible IN(&EmployeesList)
		|	AND NOT Events.DeletionMark";
	
	Query.SetParameter("CurrentDateTimeSession",			CurrentSessionDate());
	Query.SetParameter("EmployeesList",						EmployeesList);
	Query.SetParameter("EndOfDayIfCurrentDateTimeSession",	EndOfDay(CurrentSessionDate()));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(Result, SelectionDetailRecords);
	EndIf;
	
	Return Result;
	
EndFunction

// End StandardSubsystems.ToDoList

#EndRegion

#EndIf

#Region EventHandlers

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind <> "DocumentForm"
		AND FormKind <> "ObjectForm" Then
		Return;
	EndIf;
	
	EventType = Undefined; 
	
	If Parameters.Property("Key") AND ValueIsFilled(Parameters.Key) Then
		EventType	= DriveServerCall.ObjectAttributeValue(Parameters.Key, "EventType");
	EndIf;
	
	// If the document is copied that we get event type from copied document.
	If Not ValueIsFilled(EventType) Then
		If Parameters.Property("CopyingValue")
			AND ValueIsFilled(Parameters.CopyingValue) Then
			EventType = DriveServerCall.ObjectAttributeValue(Parameters.CopyingValue, "EventType");
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(EventType) Then
		If Parameters.Property("FillingValues") 
			AND TypeOf(Parameters.FillingValues) = Type("Structure") Then
			If Parameters.FillingValues.Property("EventType") Then
				EventType	= Parameters.FillingValues.EventType;
			EndIf;
		EndIf;
	EndIf;
	
	StandardProcessing = False;
	EventForms = DriveServerCall.EventGetOperationKindMapToForms();
	SelectedForm = EventForms[EventType];
	If SelectedForm = Undefined Then
		SelectedForm = "DocumentForm";
	EndIf;

EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	
	Fields.Add("Date");
	Fields.Add("EventType");
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	StandardProcessing = False;
	
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Event: %1 dated %2'; ru = 'Событие: %1 от %2';pl = 'Wydarzenie: %1 z dn. %2';es_ES = 'Evento: %1 fechado %2';es_CO = 'Evento: %1 fechado %2';tr = 'Etkinlik: %1, tarihi %2';it = 'Evento: %1 datato %2';de = 'Ereignis: %1 datiert %2'"),
		Data.EventType,
		Format(Data.Date, "DLF=D"));
	
EndProcedure

#EndRegion

