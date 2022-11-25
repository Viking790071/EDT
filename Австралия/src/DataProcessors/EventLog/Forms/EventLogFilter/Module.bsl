
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FillImportanceAndStatus();
	FillFilterParameters();
	
	DefaultEvents = Parameters.DefaultEvents;
	If Not CommonClientServer.ValueListsAreEqual(DefaultEvents, Events) Then
		EventsToDisplay = Events.Copy();
	EndIf;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject, "DataGroup, TransactionsGroup, OthersGroup");
	
	Items.SessionDataSeparation.Visible = Not Common.SeparatedDataUsageAvailable();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EventLogFilterItemValueChoice"
	   AND Source = ThisObject Then
		If PropertyCompositionEditorItemName = Items.Users.Name Then
			UsersList = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.Events.Name Then
			Events = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.Computers.Name Then
			Computers = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.Applications.Name Then
			Applications = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.Metadata.Name Then
			Metadata = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.WorkingServers.Name Then
			WorkingServers = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.MainIPPorts.Name Then
			MainIPPorts = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.AdditionalIPPorts.Name Then
			AdditionalIPPorts = Parameter;
		ElsIf PropertyCompositionEditorItemName = Items.SessionDataSeparation.Name Then
			SessionDataSeparation = Parameter;
		EndIf;
	EndIf;
	
	EventsToDisplay.Clear();
	
	If Events.Count() = 0 Then
		Events = DefaultEvents;
		Return;
	EndIf;
	
	If Not CommonClientServer.ValueListsAreEqual(DefaultEvents, Events) Then
		EventsToDisplay = Events.Copy();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ChoiceCompletion(Item, ChoiceData, StandardProcessing)
	
	Var ListToEdit, ParametersToSelect;
	
	StandardProcessing = False;
	
	PropertyCompositionEditorItemName = Item.Name;
	
	If PropertyCompositionEditorItemName = Items.Users.Name Then
		ListToEdit = UsersList;
		ParametersToSelect = "User";
	ElsIf PropertyCompositionEditorItemName = Items.Events.Name Then
		ListToEdit = Events;
		ParametersToSelect = "Event";
	ElsIf PropertyCompositionEditorItemName = Items.Computers.Name Then
		ListToEdit = Computers;
		ParametersToSelect = "Computer";
	ElsIf PropertyCompositionEditorItemName = Items.Applications.Name Then
		ListToEdit = Applications;
		ParametersToSelect = "ApplicationName";
	ElsIf PropertyCompositionEditorItemName = Items.Metadata.Name Then
		ListToEdit = Metadata;
		ParametersToSelect = "Metadata";
	ElsIf PropertyCompositionEditorItemName = Items.WorkingServers.Name Then
		ListToEdit = WorkingServers;
		ParametersToSelect = "ServerName";
	ElsIf PropertyCompositionEditorItemName = Items.MainIPPorts.Name Then
		ListToEdit = MainIPPorts;
		ParametersToSelect = "Port";
	ElsIf PropertyCompositionEditorItemName = Items.AdditionalIPPorts.Name Then
		ListToEdit = AdditionalIPPorts;
		ParametersToSelect = "SyncPort";
	ElsIf PropertyCompositionEditorItemName = Items.SessionDataSeparation.Name Then
		FormParameters = New Structure;
		FormParameters.Insert("CurrentFilter", SessionDataSeparation);
		OpenForm("DataProcessor.EventLog.Form.SessionDataSeparation", FormParameters, ThisObject);
		Return;
	Else
		StandardProcessing = True;
		Return;
	EndIf;
	
	FormParameters = New Structure;
	
	FormParameters.Insert("ListToEdit", ListToEdit);
	FormParameters.Insert("ParametersToSelect", ParametersToSelect);
	
	// Opening the property editor.
	OpenForm("DataProcessor.EventLog.Form.PropertyCompositionEditor",
	             FormParameters,
	             ThisObject);
	
EndProcedure

&AtClient
Procedure EventsClearing(Item, StandardProcessing)
	
	Events = DefaultEvents;
	
EndProcedure

&AtClient
Procedure FilterPeriodOnChange(Item)
	
	NotificationHandler = New NotifyDescription("FilterIntervalOnChangeCompletion", ThisObject);
	
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = FilterPeriod;
	Dialog.Show(NotificationHandler);
	
EndProcedure

&AtClient
Procedure FilterIntervalOnChangeCompletion(Period, AdditionalParameters) Export
	
	If Period = Undefined Then
		Return;
	EndIf;
	
	FilterPeriod = Period;
	FilterPeriodStartDate    = FilterPeriod.StartDate;
	FilterPeriodEndDate = FilterPeriod.EndDate;
	
EndProcedure

&AtClient
Procedure FilterPeriodDateOnChange(Item)
	
	FilterPeriod.Variant       = StandardPeriodVariant.Custom;
	FilterPeriod.StartDate    = FilterPeriodStartDate;
	FilterPeriod.EndDate = FilterPeriodEndDate;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetFilterAndCloseForm(Command)
	
	NotifyChoice(
		New Structure("Event, Filter", 
			"EventLogFilterSet", 
			GetEventLogFilter()));
	
EndProcedure

&AtClient
Procedure SelectSeverityCheckBoxes(Command)
	For Each ListItem In Importance Do
		ListItem.Check = True;
	EndDo;
EndProcedure

&AtClient
Procedure ClearSeverityCheckBoxes(Command)
	For Each ListItem In Importance Do
		ListItem.Check = False;
	EndDo;
EndProcedure

&AtClient
Procedure SelectTransactionStatusCheckBoxes(Command)
	For Each ListItem In TransactionStatus Do
		ListItem.Check = True;
	EndDo;
EndProcedure

&AtClient
Procedure ClearTransactionStatusCheckBoxes(Command)
	For Each ListItem In TransactionStatus Do
		ListItem.Check = False;
	EndDo;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillImportanceAndStatus()
	// Filling the Importance form item
	Importance.Add("Error",         String(EventLogLevel.Error));
	Importance.Add("Warning", String(EventLogLevel.Warning));
	Importance.Add("Information",     String(EventLogLevel.Information));
	Importance.Add("Note",     String(EventLogLevel.Note));
	
	// Filling the TransactionStatus form item
	TransactionStatus.Add("NotApplicable", String(EventLogEntryTransactionStatus.NotApplicable));
	TransactionStatus.Add("Committed", String(EventLogEntryTransactionStatus.Committed));
	TransactionStatus.Add("Unfinished",   String(EventLogEntryTransactionStatus.Unfinished));
	TransactionStatus.Add("RolledBack",      String(EventLogEntryTransactionStatus.RolledBack));
	
EndProcedure

&AtServer
Procedure FillFilterParameters()
	
	FilterParameterList = Parameters.Filter;
	HasFilterByLevel  = False;
	HasFilterByStatus = False;
	
	For Each FilterParameter In FilterParameterList Do
		ParameterName = FilterParameter.Presentation;
		Value     = FilterParameter.Value;
		
		If Upper(ParameterName) = Upper("StartDate") Then
			// StartDate
			FilterPeriod.StartDate = Value;
			FilterPeriodStartDate  = Value;
			
		ElsIf Upper(ParameterName) = Upper("EndDate") Then
			// EndDate
			FilterPeriod.EndDate = Value;
			FilterPeriodEndDate  = Value;
			
		ElsIf Upper(ParameterName) = Upper("User") Then
			// User
			UsersList = Value;
			
		ElsIf Upper(ParameterName) = Upper("Event") Then
			// Event
			Events = Value;
			
		ElsIf Upper(ParameterName) = Upper("Computer") Then
			// Computer
			Computers = Value;
			
		ElsIf Upper(ParameterName) = Upper("ApplicationName") Then
			// ApplicationName
			Applications = Value;
			
		ElsIf Upper(ParameterName) = Upper("Comment") Then
			// Comment
			Comment = Value;
		 	
		ElsIf Upper(ParameterName) = Upper("Metadata") Then
			// Metadata
			Metadata = Value;
			
		ElsIf Upper(ParameterName) = Upper("Data") Then
			// Data
			Data = Value;
			
		ElsIf Upper(ParameterName) = Upper("DataPresentation") Then
			// DataPresentation
			DataPresentation = Value;
			
		ElsIf Upper(ParameterName) = Upper("TransactionID") Then
			// TransactionID
			TransactionID = Value;
			
		ElsIf Upper(ParameterName) = Upper("ServerName") Then
			// ServerName
			WorkingServers = Value;
			
		ElsIf Upper(ParameterName) = Upper("Session") Then
			// Session
			Sessions = Value;
			SessionsString = "";
			For Each SessionNumber In Sessions Do
				SessionsString = SessionsString + ?(SessionsString = "", "", "; ") + SessionNumber;
			EndDo;
			
		ElsIf Upper(ParameterName) = Upper("Port") Then
			// Port
			MainIPPorts = Value;
			
		ElsIf Upper(ParameterName) = Upper("SyncPort") Then
			// SyncPort
			AdditionalIPPorts = Value;
			
		ElsIf Upper(ParameterName) = Upper("Level") Then
			// Level
			HasFilterByLevel = True;
			For Each ValueListItem In Importance Do
				If Value.FindByValue(ValueListItem.Value) <> Undefined Then
					ValueListItem.Check = True;
				EndIf;
			EndDo;
			
		ElsIf Upper(ParameterName) = Upper("TransactionStatus") Then
			// TransactionStatus
			HasFilterByStatus = True;
			For Each ValueListItem In TransactionStatus Do
				If Value.FindByValue(ValueListItem.Value) <> Undefined Then
					ValueListItem.Check = True;
				EndIf;
			EndDo;
			
		ElsIf Upper(ParameterName) = Upper("SessionDataSeparation") Then
			
			If TypeOf(Value) = Type("ValueList") Then
				SessionDataSeparation = Value.Copy();
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If Not HasFilterByLevel Then
		For Each ValueListItem In Importance Do
			ValueListItem.Check = True;
		EndDo;
	EndIf;
	
	If Not HasFilterByStatus Then
		For Each ValueListItem In TransactionStatus Do
			ValueListItem.Check = True;
		EndDo;
	ElsIf HasFilterByStatus Or ValueIsFilled(TransactionID) Then
		Items.TransactionsGroup.Title = Items.TransactionsGroup.Title + " *";
	EndIf;
	
	If ValueIsFilled(WorkingServers)
		Or ValueIsFilled(MainIPPorts)
		Or ValueIsFilled(AdditionalIPPorts)
		Or ValueIsFilled(SessionDataSeparation)
		Or ValueIsFilled(Comment) Then
		Items.OthersGroup.Title = Items.OthersGroup.Title + " *";
	EndIf;
	
EndProcedure

&AtClient
Function GetEventLogFilter()
	
	Sessions.Clear();
	Page = SessionsString;
	Page = StrReplace(Page, ";", " ");
	Page = StrReplace(Page, ",", " ");
	Page = TrimAll(Page);
	TS = New TypeDescription("Number");
	
	While Not IsBlankString(Page) Do
		Pos = StrFind(Page, " ");
		
		If Pos = 0 Then
			Value = TS.AdjustValue(Page);
			Page = "";
		Else
			Value = TS.AdjustValue(Left(Page, Pos-1));
			Page = TrimAll(Mid(Page, Pos+1));
		EndIf;
		
		If Value <> 0 Then
			Sessions.Add(Value);
		EndIf;
	EndDo;
	
	Filter = New ValueList;
	
	// Start and end dates
	If FilterPeriodStartDate <> '00010101000000' Then 
		Filter.Add(FilterPeriodStartDate, "StartDate");
	EndIf;
	If FilterPeriodEndDate <> '00010101000000' Then
		Filter.Add(FilterPeriodEndDate, "EndDate");
	EndIf;
	
	// User
	If UsersList.Count() > 0 Then 
		Filter.Add(UsersList, "User");
	EndIf;
	
	// Event
	If Events.Count() > 0 Then 
		Filter.Add(Events, "Event");
	EndIf;
	
	// Computer
	If Computers.Count() > 0 Then 
		Filter.Add(Computers, "Computer");
	EndIf;
	
	// ApplicationName
	If Applications.Count() > 0 Then 
		Filter.Add(Applications, "ApplicationName");
	EndIf;
	
	// Comment
	If Not IsBlankString(Comment) Then 
		Filter.Add(Comment, "Comment");
	EndIf;
	
	// Metadata
	If Metadata.Count() > 0 Then 
		Filter.Add(Metadata, "Metadata");
	EndIf;
	
	// Data
	If (Data <> Undefined) AND (Not Data.IsEmpty()) Then
		Filter.Add(Data, "Data");
	EndIf;
	
	// DataPresentation
	If Not IsBlankString(DataPresentation) Then 
		Filter.Add(DataPresentation, "DataPresentation");
	EndIf;
	
	// TransactionID
	If Not IsBlankString(TransactionID) Then 
		Filter.Add(TransactionID, "TransactionID");
	EndIf;
	
	// ServerName
	If WorkingServers.Count() > 0 Then 
		Filter.Add(WorkingServers, "ServerName");
	EndIf;
	
	// Session
	If Sessions.Count() > 0 Then 
		Filter.Add(Sessions, "Session");
	EndIf;
	
	// Port
	If MainIPPorts.Count() > 0 Then 
		Filter.Add(MainIPPorts, "Port");
	EndIf;
	
	// SyncPort
	If AdditionalIPPorts.Count() > 0 Then 
		Filter.Add(AdditionalIPPorts, "SyncPort");
	EndIf;
	
	// SessionDataSeparation
	If SessionDataSeparation.Count() > 0 Then 
		Filter.Add(SessionDataSeparation, "SessionDataSeparation");
	EndIf;
	
	// Level
	LevelList = New ValueList;
	For Each ValueListItem In Importance Do
		If ValueListItem.Check Then 
			LevelList.Add(ValueListItem.Value, ValueListItem.Presentation);
		EndIf;
	EndDo;
	If LevelList.Count() > 0 AND LevelList.Count() <> Importance.Count() Then
		Filter.Add(LevelList, "Level");
	EndIf;
	
	// TransactionStatus
	StatusesList = New ValueList;
	For Each ValueListItem In TransactionStatus Do
		If ValueListItem.Check Then 
			StatusesList.Add(ValueListItem.Value, ValueListItem.Presentation);
		EndIf;
	EndDo;
	If StatusesList.Count() > 0 AND StatusesList.Count() <> TransactionStatus.Count() Then
		Filter.Add(StatusesList, "TransactionStatus");
	EndIf;
	
	Return Filter;
	
EndFunction

#EndRegion
