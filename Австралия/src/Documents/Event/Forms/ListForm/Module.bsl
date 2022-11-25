
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PaintList();
	
	SetFilterToDoList();
	SetFilterEventType();
	
	If Parameters.Property("Contact") AND ValueIsFilled(Parameters.Contact) Then
		ContextContact	= Parameters.Contact;
		CommonClientServer.SetDynamicListFilterItem(List, "TPParticipants.Contact", Parameters.Contact);
		Items.FilterCounterparty.Visible = False;
	EndIf;
	
	If Parameters.Property("BasisDocument") AND ValueIsFilled(Parameters.BasisDocument) Then
		FilterBasis = Parameters.BasisDocument;
		CommonClientServer.SetDynamicListFilterItem(List, "BasisDocument", FilterBasis);
	EndIf;
	
	ContextOpening = Parameters.Property("ToDoList") Or Parameters.Property("Contact") Or Parameters.Property("BasisDocument");
	
	If Not ContextOpening Then
		WorkWithFilters.RestoreFilterSettings(ThisObject, List,,,,FilterEventType);
	EndIf;
	
	PeriodPresentation = WorkWithFiltersClientServer.RefreshPeriodPresentation(FilterPeriod);
	
	ContactInformationPanel.OnCreateAtServer(ThisObject, "ContactInformation");
	
	UseDocumentEvent = True;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	If Not ContextOpening Then
		SaveFilterSettings();
	EndIf; 
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_JobAndEventStatuses" Then
		PaintList();
	EndIf;
	
	If ContactInformationPanelClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
		RefreshContactInformationPanelServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Item.CurrentRow) <> Type("DynamicListGroupRow") Then
		
		AttachIdleHandler("HandleActivateListRow", 0.2, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	FillingValue = New Structure;
	If ValueIsFilled(Parameters.EventType) Then
		FillingValue.Insert("EventType", Parameters.EventType);
	EndIf;
	FormParameters = New Structure;
	
	If ValueIsFilled(FilterBasis) Then
		
		Cancel = True;
		
		FillingValue.Insert("FillingBasis", FilterBasis);
		FormParameters.Insert("FillingValues", FillingValue);
		OpenForm("Document.Event.ObjectForm", FormParameters);
		
	ElsIf ValueIsFilled(ContextContact) Then
		
		Cancel = True;
		
		FillingValue.Insert("FillingBasis", ContextContact);
		FormParameters.Insert("FillingValues", FillingValue);
		OpenForm("Document.Event.ObjectForm", FormParameters);
		
	Else
		
		FilterByCounterparty = GetFilterByCounterparty();
		
		If FilterByCounterparty <> Undefined Then
			
			Cancel = True;
			
			FillingValue.Insert("FillingBasis", FilterByCounterparty);
			FormParameters.Insert("FillingValues", FillingValue);
			OpenForm("Document.Event.ObjectForm", FormParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithFiltersClient.PeriodPresentationSelectPeriod(ThisObject, , "EventBegin");
	
EndProcedure

&AtClient
Procedure FilterCounterpartyChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	CounterpartyContacts = GetCounterpartyContacts(SelectedValue);
	
	SetLabelAndListFilter("TPParticipants.Contact", Item.Parent.Name, CounterpartyContacts, String(SelectedValue));
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterResponsibleChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Responsible", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterEventTypeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("EventType", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterStateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("State", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterProjectChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Project", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure CollapseExpandFiltesPanelClick(Item)
	
	NewValueVisible = Not Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisible);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateEvent(Command)
	
	FillingValue = New Structure;
	FillingValue.Insert("EventType", PredefinedValue("Enum.EventTypes." + Mid(Command.Name, 7)));
	If ValueIsFilled(FilterBasis) Then
		FillingValue.Insert("FillingBasis", FilterBasis);
	ElsIf ValueIsFilled(ContextContact) Then
		FillingValue.Insert("FillingBasis", ContextContact);
	Else
		FillingValue.Insert("FillingBasis", New Structure);
		If ValueIsFilled(FilterResponsible) Then
			FillingValue.FillingBasis.Insert("Responsible", FilterResponsible);
		EndIf;
		If ValueIsFilled(FilterState) Then
			FillingValue.FillingBasis.Insert("State", FilterState);
		EndIf;
		FilterByCounterparty = GetFilterByCounterparty();
		If ValueIsFilled(FilterByCounterparty) Then
			FillingValue.FillingBasis.Insert("Contact", FilterByCounterparty);
		EndIf;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValue);
	
	OpenForm("Document.Event.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region CommonProceduresAndFunctions

&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	SelectionJobAndEventStatuses = Catalogs.JobAndEventStatuses.Select();
	While SelectionJobAndEventStatuses.Next() Do
		
		BackColor = SelectionJobAndEventStatuses.Color.Get();
		If TypeOf(BackColor) <> Type("Color") Then
			Continue;
		EndIf; 
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("State");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = SelectionJobAndEventStatuses.Ref;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = NStr("en = 'By event state'; ru = 'По состоянию события';pl = 'Wg statusu wydarzenia';es_ES = 'Por el estado de evento';es_CO = 'Por el estado de evento';tr = 'Etkinlik durumuna göre';it = 'Per stato evento';de = 'Nach Ereignisstatus'") + " " + SelectionJobAndEventStatuses.Description;
	
	EndDo;
	
EndProcedure

&AtServer
Procedure SetFilterToDoList()
	
	If Not Parameters.Property("ToDoList") Then
		Return;
	EndIf;
	
	AutoTitle	= False;
	Title		= NStr("en = 'Events'; ru = 'События';pl = 'Wydarzenia';es_ES = 'Eventos';es_CO = 'Eventos';tr = 'Etkinlikler';it = 'Eventi';de = 'Ereignisse'");
	CurDate		= CurrentSessionDate();
	
	CommonClientServer.SetDynamicListFilterItem(List, "DeletionMark", False);
	
	StateList = New ValueList;
	StateList.Add(Catalogs.JobAndEventStatuses.Canceled);
	StateList.Add(Catalogs.JobAndEventStatuses.Completed);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	JobAndEventStatuses.Ref
		|FROM
		|	Catalog.JobAndEventStatuses AS JobAndEventStatuses
		|WHERE
		|	JobAndEventStatuses.DeletionMark = FALSE
		|	AND NOT JobAndEventStatuses.Ref IN (&StateList)";
	
	Query.SetParameter("StateList", StateList);
	Selection = Query.Execute().Select();
	StateList.Clear();
	
	While Selection.Next() Do
		StateList.Add(Selection.Ref);
	EndDo;
	
	WorkWithFilters.AttachFilterLabelsFromArray(ThisObject, "State", "States", StateList.UnloadValues());
	WorkWithFilters.SetListFilter(ThisObject, List, "State");
	
	CurrentUserRef = Users.CurrentUser();
	WorkWithFilters.AttachFilterLabelsFromArray(ThisObject, "Responsible", "Responsibles", 
							DriveServer.GetUserEmployees(CurrentUserRef).UnloadColumn("Employee"));
	WorkWithFilters.SetListFilter(ThisObject, List, "Responsible");
	
	If Parameters.Property("PastPerformance") Then
		
		Title = Title + ": " + NStr("en = 'expired'; ru = 'просроченные';pl = 'przedawnione';es_ES = 'caducado';es_CO = 'caducado';tr = 'süresi bitmiş';it = 'scaduto';de = 'abgelaufen'");
		DriveClientServer.SetListFilterItem(
			List, 
			"EventBegin", 
			Date('00010101'), 
			True, 
			DataCompositionComparisonType.NotEqual
		);
		DriveClientServer.SetListFilterItem(
			List, 
			"EventEnding", 
			CurrentSessionDate(), 
			True, 
			DataCompositionComparisonType.Less
		);
		Items.PeriodPresentation.Visible	= False;
		
	ElsIf Parameters.Property("ForToday") Then
		
		Title = Title + ": " + NStr("en = 'for today'; ru = 'на сегодня';pl = 'na dzisiaj';es_ES = 'para hoy';es_CO = 'para hoy';tr = 'bugün itibarıyla';it = 'odierni';de = 'für heute'");
		DriveClientServer.SetListFilterItem(
			List, 
			"EventBegin", 
			EndOfDay(CurrentSessionDate()), 
			True, 
			DataCompositionComparisonType.LessOrEqual);
		DriveClientServer.SetListFilterItem(
			List, 
			"EventEnding", 
			CurrentSessionDate(), 
			True, 
			DataCompositionComparisonType.GreaterOrEqual);
		Items.PeriodPresentation.Visible	= False;
		
	ElsIf Parameters.Property("InProcess") Then
		
		Title = Title + ": " + NStr("en = 'in process'; ru = 'В работе';pl = 'W toku';es_ES = 'en proceso';es_CO = 'en proceso';tr = 'işlemde';it = 'in lavorazione';de = 'in bearbeitung'");
		
	EndIf;
	
	If Parameters.Property("Responsible") Then
		Title = Title + ", " + NStr("en = 'responsible'; ru = 'ответственный';pl = 'odpowiedzialny';es_ES = 'responsable';es_CO = 'responsable';tr = 'sorumlu';it = 'responsabile';de = 'verantwortlich'") + " " + Parameters.Responsible.Initials;
	EndIf;

	If Items.PeriodPresentation.Visible Then
		PeriodPresentation = WorkWithFiltersClientServer.RefreshPeriodPresentation(FilterPeriod);
	EndIf;
	
	WorkWithFilters.RefreshLabelItems(ThisObject);
	
EndProcedure

&AtServer
Procedure SetFilterEventType()
	
	If Not ValueIsFilled(Parameters.EventType) Then
		Return;
	Else
		FilterEventType = Parameters.EventType;
	EndIf;
	
	AutoTitle = False;
	Items.FilterEventType.Visible	= False;
	Items.ListGroupCreate.Visible	= False;
	Items.FormCreate.Visible		= True;
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"EventType",
		Parameters.EventType
	);
	
	Items.IncomingOutgoing.Visible	= Parameters.EventType <> Enums.EventTypes.SMS;
	Items.Projects.Visible			= Not (Parameters.EventType = Enums.EventTypes.SMS
														Or Parameters.EventType = Enums.EventTypes.Email);
														
	If Parameters.EventType = Enums.EventTypes.PhoneCall Then
		Title = NStr("en = 'Events: phone calls'; ru = 'События: телефонные звонки';pl = 'Wydarzenia: połączenia telefoniczne';es_ES = 'Eventos: llamadas telefónicas';es_CO = 'Eventos: llamadas';tr = 'Etkinlikler: telefon aramaları';it = 'Eventi: telefonate';de = 'Ereignisse: Telefonate'");
	ElsIf Parameters.EventType = Enums.EventTypes.Email Then
		Title = NStr("en = 'Events: emails'; ru = 'События: электронные письма';pl = 'Wydarzenia: wiadomości e-mail';es_ES = 'Eventos: correos electrónicos';es_CO = 'Eventos: Email';tr = 'Etkinlikler: e-postalar';it = 'Eventi: messaggi di posta elettronica';de = 'Ereignisse: E-Mails'");
	ElsIf Parameters.EventType = Enums.EventTypes.SMS Then
		Title = NStr("en = 'Events: SMS'; ru = 'События: сообщения SMS';pl = 'Wydarzenia: SMS';es_ES = 'Eventos: SMS';es_CO = 'Eventos: SMS';tr = 'Etkinlikler: SMS';it = 'Eventi: messaggi SMS';de = 'Ereignisse: SMS'");
	ElsIf Parameters.EventType = Enums.EventTypes.PersonalMeeting Then
		Title = NStr("en = 'Events: personal meetings'; ru = 'События: личные встречи';pl = 'Wydarzenia: spotkania osobiste ';es_ES = 'Eventos: reuniones personales';es_CO = 'Eventos: Reuniones';tr = 'Etkinlikler: bireysel toplantılar';it = 'Eventi: incontri di persona';de = 'Ereignisse: persönliche Treffen'");
	ElsIf Parameters.EventType = Enums.EventTypes.Other Then
		Title = NStr("en = 'Events: other'; ru = 'События: прочие';pl = 'Wydarzenia: inne';es_ES = 'Eventos: otro';es_CO = 'Eventos: Otro';tr = 'Etkinlikler: diğer';it = 'Eventi: altri';de = 'Ereignisse: Sonstige'");
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetCounterpartyContacts(Counterparty)
	
	Contacts = New Array;
	
	If Not ValueIsFilled(Counterparty) Then
		Return Contacts;
	EndIf;
	
	Contacts.Add(Counterparty);
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	ContactPersons.Ref
		|FROM
		|	Catalog.ContactPersons AS ContactPersons
		|WHERE
		|	ContactPersons.Owner = &Counterparty
		|	AND ContactPersons.DeletionMark = FALSE";
	
	Query.SetParameter("Counterparty", Counterparty);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Contacts.Add(Selection.Ref);
	EndDo;
	
	Return Contacts;
	
EndFunction

&AtClient
Procedure HandleActivateListRow()
	
	RefreshContactInformationPanelServer();
	
EndProcedure

&AtClient
Function GetFilterByCounterparty()
	
	FindedRows = LabelData.FindRows(New Structure("FilterFieldName", "TPParticipants.Contact"));
	FilterByCounterparty = Undefined;
	
	For Each FindedRow In FindedRows Do
		If TypeOf(FindedRow.Label) = Type("ValueList") Then
			For Each ListItem In FindedRow.Label Do
				If TypeOf(ListItem.Value) = Type("CatalogRef.Counterparties") Then
					FilterByCounterparty = ListItem.Value;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return FilterByCounterparty;
	
EndFunction

#EndRegion

#Region ContactInformationPanel

&AtServer
Procedure RefreshContactInformationPanelServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	Counterparties.Ref AS Counterparty
	|FROM
	|	Document.Event.Participants AS EventParticipants
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON EventParticipants.Contact = Counterparties.Ref
	|WHERE
	|	EventParticipants.Ref = &Event";
	
	Query.SetParameter("Event", Items.List.CurrentRow);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ContactInformationPanel.RefreshPanelData(ThisObject, Selection.Counterparty);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ContactInformationPanelClient.ContactInformationPanelDataSelection(ThisObject, Item, SelectedRow, Field, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataOnActivateRow(Item)
	
	ContactInformationPanelClient.ContactInformationPanelDataOnActivateRow(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataExecuteCommand(Command)
	
	ContactInformationPanelClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region FilterLabel

&AtServer
Procedure SetLabelAndListFilter(ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation="")
	
	If ValuePresentation="" Then
		ValuePresentation=String(SelectedValue);
	EndIf; 
	
	WorkWithFilters.AttachFilterLabel(ThisObject, ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation);
	WorkWithFilters.SetListFilter(ThisObject, List, ListFilterFieldName,,True);
	
EndProcedure

&AtClient
Procedure Attachable_LabelURLProcessing(Item, URLFS, StandardProcessing)
	
	StandardProcessing = False;
	
	LabelID = Mid(Item.Name, StrLen("Label_")+1);
	DeleteFilterLabel(LabelID);
	
EndProcedure

&AtServer
Procedure DeleteFilterLabel(LabelID)
	
	WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, LabelID);

EndProcedure

&AtServer
Procedure SaveFilterSettings()
	
	WorkWithFilters.SaveFilterSettings(ThisObject,,,FilterEventType);
	
EndProcedure

#EndRegion

#Region Email
	
&AtClient
Procedure FilterIncomingOutgoingOnChange(Item)
	
	SetFilterIncomingOutgoing();
	
EndProcedure

&AtClient
Procedure FilterAccountChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("UserAccount", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;

EndProcedure

&AtServer
Procedure SetFilterIncomingOutgoing()
	
	If ValueIsFilled(FilterIncomingOutgoing) Then
		DriveClientServer.SetListFilterItem(List, "IncomingOutgoing", FilterIncomingOutgoing);
	Else
		DriveClientServer.DeleteListFilterItem(List, "IncomingOutgoing");
	EndIf;
	
EndProcedure

#EndRegion