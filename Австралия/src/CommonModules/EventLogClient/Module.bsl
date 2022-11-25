#Region Public

// Write the message to the event log.
// If WriteEvents = True, the message is written immediately, through a server call.
// If WriteEvents is False (by default), the message is placed in a queue to be written later, with 
// the next call of this or another procedure. The queue of the messages to be written is passed in 
// the MessagesForEventLog parameter.
//
//  Parameters:
//   EventName          - String - the name of the event used for event log.
//   LevelPresentation - String - description of the event level that determines the event level 
//                                  when writing the event data on server.
//                                  For example: "Error", "Warning".
//                                  These values correspond to the names of the EventLogLevel enumeration items.
//   Comment         - String - the comment to the log event.
//   EventDate         - Date   - the exact occurrence date of the event described in the message. 
//                                  This date will be added to the beginning of the comment.
//   WriteEvents     - Boolean - write all accumulated events to the event log, through a server 
//                                  call.
//
// Example:
//  EventLogClient.AddMessageForEventLog(EventLogEvent(), "Warning",
//     NStr("en = 'Cannot establish Internet connection to check for updates."));
//
Procedure AddMessageForEventLog(Val EventName, Val LevelPresentation = "Information", 
	Val Comment = "", Val EventDate = "", Val WriteEvents = False) Export
	
	ProcedureName = "EventLogClient.AddMessageForEventLog";
	CommonClientServer.CheckParameter(ProcedureName, "EventName", EventName, Type("String"));
	CommonClientServer.CheckParameter(ProcedureName, "LevelPresentation", LevelPresentation, Type("String"));
	CommonClientServer.CheckParameter(ProcedureName, "Comment", Comment, Type("String"));
	If EventDate <> "" Then
		CommonClientServer.CheckParameter(ProcedureName, "EventDate", EventDate, Type("Date"));
	EndIf;
	
	ParameterName = "StandardSubsystems.MessagesForEventLog";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New ValueList);
	EndIf;
	
	If TypeOf(EventDate) = Type("Date") Then
		EventDate = Format(EventDate, "DLF=DT");
	EndIf;
	
	MessageStructure = New Structure;
	MessageStructure.Insert("EventName", EventName);
	MessageStructure.Insert("LevelPresentation", LevelPresentation);
	MessageStructure.Insert("Comment", Comment);
	MessageStructure.Insert("EventDate", EventDate);
	
	ApplicationParameters["StandardSubsystems.MessagesForEventLog"].Add(MessageStructure);
	
	If WriteEvents Then
		EventLogServerCall.WriteEventsToEventLog(ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
	EndIf;
	
EndProcedure

// Opens the event log form with the set filter.
//
// Parameters:
//  Filter - Structure - contains the following properties:
//     * User              - String, ValueList - the name of infobase user, or the list of names of 
//                                                            infobase users.
//     * EventLogEvent - String, Array - the ID of the event.
//     * StartDate                - Date           - the start date of the interval of displayed events.
//     * EndDate                - Date           - the end date of the interval of displayed events.
//     * Data                    - Arbitrary   - data of any type.
//     * Session                     - ValueList - the list of selected sessions.
//     * Level                   - String, Array - presentation of importance level of the log event.
//                                                    
//     * ApplicationName             - Array         - array of the application IDs.
//  Owner - ClientApplicationForm - the form used to open the event log.
//
Procedure OpenEventLog(Val Filter = Undefined, Owner = Undefined) Export
	
	OpenForm("DataProcessor.EventLog.Form", Filter, Owner);
	
EndProcedure

#EndRegion

#Region Internal

// Opens the form for viewing additional event data.
//
// Parameters:
//  CurrentData - Value table row - a row of the event log.
//
Procedure OpenDataForViewing(CurrentData) Export
	
	If CurrentData = Undefined Or CurrentData.Data = Undefined Then
		ShowMessageBox(, NStr("ru = 'Эта запись журнала регистрации не связана с данными (см. колонку ""Данные"")'; en = 'The event log record is not linked to data (see the Data column)'; pl = 'Ten wpis dziennika wydarzeń nie jest związany z danymi (zob. kolumna """"Dane"""")';es_ES = 'Esta entrada del registro de eventos no está relacionada con los datos (ver la columna ""Datos"")';es_CO = 'Esta entrada del registro de eventos no está relacionada con los datos (ver la columna ""Datos"")';tr = 'Olay günlüğü kaydı verilere bağlantılı değil (Veri sütununa bakın)';it = 'Questa voce di registro non è correlata ai dati (vedere la colonna ""Dati"")';de = 'Dieser Ereignisprotokolleintrag bezieht sich nicht auf Daten (siehe Spalte ""Daten"")'"));
		Return;
	EndIf;
	
	Try
		ShowValue(, CurrentData.Data);
	Except
		WarningText = NStr("ru = 'Эта запись журнала регистрации связана с данными, но отобразить их невозможно.
									|%1'; 
									|en = 'The event log record is linked to data that cannot be displayed.
									|%1'; 
									|pl = 'Ten wpis dziennika wydarzeń jest połączony z danymi, ale nie można ich wyświetlić.
									|%1';
									|es_ES = 'Este registro de pantalla del registro de eventos está conectado con los datos, pero ellos pueden no estar visualizados.
									|%1';
									|es_CO = 'Este registro de pantalla del registro de eventos está conectado con los datos, pero ellos pueden no estar visualizados.
									|%1';
									|tr = 'Olay günlüğü kaydı, görüntülenemeyen verilere bağlantılı.
									|%1';
									|it = 'Questa voce di registro è associata ai dati, ma non può essere visualizzata.
									|%1';
									|de = 'Dieser Ereignisprotokoll-Überwachungsdatensatz ist mit den Daten verbunden, sie können jedoch nicht angezeigt werden.
									|%1'");
		If CurrentData.Event = "_$Data$_.Delete" Then 
			// This is a deletion event.
			WarningText =
					StringFunctionsClientServer.SubstituteParametersToString(WarningText, NStr("ru = 'Данные удалены из информационной базы'; en = 'The data was deleted from the infobase'; pl = 'Dane są usunięte z informacyjnej bazy';es_ES = 'Datos se han borrado de la infobase';es_CO = 'Datos se han borrado de la infobase';tr = 'Veri veritabanından silindi';it = 'I dati sono stati eliminati dall''infobase';de = 'Daten werden aus der Infobase gelöscht'"));
		Else
			WarningText =
				StringFunctionsClientServer.SubstituteParametersToString(WarningText, NStr("ru = 'Возможно, данные удалены из информационной базы'; en = 'Perhaps the data was deleted from the infobase'; pl = 'Być może, dane są usunięte z bazy informacyjnej';es_ES = 'Probablemente los datos se hayan borrado de la infobase.';es_CO = 'Probablemente los datos se hayan borrado de la infobase.';tr = 'Veri veritabanından silinmiş olabilir.';it = 'Probabilmente i dati sono stati eliminati dall''infobase';de = 'Vielleicht werden die Daten aus der Infobase gelöscht.'"));
		EndIf;
		ShowMessageBox(, WarningText);
	EndTry;
	
EndProcedure

// Opens the event view form of the "Event log" data processor
// to display detailed data for the selected event.
//
// Parameters:
//  Data - Value table row - a row of the event log.
//
Procedure ViewCurrentEventInNewWindow(Data) Export
	
	If Data = Undefined Then
		Return;
	EndIf;
	
	FormUniqueKey = Data.DataAddress;
	OpenForm("DataProcessor.EventLog.Form.Event", EventLogEventToStructure(Data),, FormUniqueKey);
	
EndProcedure

// Prompts the user for the period restriction and includes it in the event log filter.
// 
//
// Parameters:
//  DateInterval - StandardPeriod, the filter date interval.
//  EventLogFilter - Structure, the event log filter.
//
Procedure SetPeriodForViewing(DateInterval, EventLogFilter, NotificationHandler = Undefined) Export
	
	// Retrieving the current period
	StartDate    = Undefined;
	EndDate = Undefined;
	EventLogFilter.Property("StartDate", StartDate);
	EventLogFilter.Property("EndDate", EndDate);
	StartDate    = ?(TypeOf(StartDate)    = Type("Date"), StartDate, '00010101000000');
	EndDate = ?(TypeOf(EndDate) = Type("Date"), EndDate, '00010101000000');
	
	If DateInterval.StartDate <> StartDate Then
		DateInterval.StartDate = StartDate;
	EndIf;
	
	If DateInterval.EndDate <> EndDate Then
		DateInterval.EndDate = EndDate;
	EndIf;
	
	// Editing the current period.
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = DateInterval;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("EventLogFilter", EventLogFilter);
	AdditionalParameters.Insert("DateInterval", DateInterval);
	AdditionalParameters.Insert("NotificationHandler", NotificationHandler);
	
	Notification = New NotifyDescription("SetViewDateIntervalCompletion", ThisObject, AdditionalParameters);
	Dialog.Show(Notification);
	
EndProcedure

// Handles selection of a single event in the event table.
//
// Parameters:
//  CurrentData - Value table row - a row of the event log.
//  Field - Value table field - field.
//  DateInterval - interval.
//  EventLogFilter - Filter - the event log filter.
//
Procedure EventsChoice(CurrentData, Field, DateInterval, EventLogFilter) Export
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Field.Name = "Data" Or Field.Name = "DataPresentation" Then
		If CurrentData.Data <> Undefined
			AND Not ValueIsFilled(CurrentData.Comment)
			AND (TypeOf(CurrentData.Data) <> Type("String")
			AND ValueIsFilled(CurrentData.Data)) Then
			
			OpenDataForViewing(CurrentData);
			Return;
		EndIf;
	EndIf;
	
	If Field.Name = "Date" Then
		SetPeriodForViewing(DateInterval, EventLogFilter);
		Return;
	EndIf;
	
	ViewCurrentEventInNewWindow(CurrentData);
	
EndProcedure

// Fills the filter according to the value in the current event column.
//
// Parameters:
//  CurrentData - Value table row.
//  CurrentItem - current item of the value table row.
//  EventLogFilter - Structure - the event log filter.
//  ExcludeColumns - Value list - the columns to exclude.
//
// Returns:
//  Boolean - True if the filter is set, False otherwise.
//
Function SetFilterByValueInCurrentColumn(CurrentData, CurrentItem, EventLogFilter, ExcludeColumns) Export
	
	If CurrentData = Undefined Then
		Return False;
	EndIf;
	
	PresentationColumnName = CurrentItem.Name;
	
	If PresentationColumnName = "SessionDataSeparationPresentation" Then
		EventLogFilter.Delete("SessionDataSeparationPresentation");
		EventLogFilter.Insert("SessionDataSeparation", CurrentData.SessionDataSeparation);
		PresentationColumnName = "SessionDataSeparation";
	EndIf;
	
	If ExcludeColumns.Find(PresentationColumnName) <> Undefined Then
		Return False;
	EndIf;
	FilterValue = CurrentData[PresentationColumnName];
	Presentation  = CurrentData[PresentationColumnName];
	
	FilterItemName = PresentationColumnName;
	If PresentationColumnName = "UserName" Then 
		FilterItemName = "User";
		FilterValue = CurrentData["User"];
	ElsIf PresentationColumnName = "ApplicationPresentation" Then
		FilterItemName = "ApplicationName";
		FilterValue = CurrentData["ApplicationName"];
	ElsIf PresentationColumnName = "EventPresentation" Then
		FilterItemName = "Event";
		FilterValue = CurrentData["Event"];
	EndIf;
	
	// Filtering by a blanked string is not allowed.
	If TypeOf(FilterValue) = Type("String") AND IsBlankString(FilterValue) Then
		// The default user has a blank name, it is allowed to filter by this user.
		If PresentationColumnName <> "UserName" Then 
			Return False;
		EndIf;
	EndIf;
	
	CurrentValue = Undefined;
	If EventLogFilter.Property(FilterItemName, CurrentValue) Then
		// Filter is already applied
		EventLogFilter.Delete(FilterItemName);
	EndIf;
	
	If FilterItemName = "Data" // Filter type is not a list but a single value.
		Or FilterItemName = "Comment"
		Or FilterItemName = "TransactionID"
		Or FilterItemName = "DataPresentation" Then
		EventLogFilter.Insert(FilterItemName, FilterValue);
	Else
		
		If FilterItemName = "SessionDataSeparation" Then
			FilterList = FilterValue.Copy();
		Else
			FilterList = New ValueList;
			FilterList.Add(FilterValue, Presentation);
		EndIf;
		
		EventLogFilter.Insert(FilterItemName, FilterList);
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#Region Private

// For internal use only.
//
Function EventLogEventToStructure(Data)
	
	If TypeOf(Data) = Type("Structure") Then
		Return Data;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Date",                    Data.Date);
	FormParameters.Insert("UserName",         Data.UserName);
	FormParameters.Insert("ApplicationPresentation", Data.ApplicationPresentation);
	FormParameters.Insert("Computer",               Data.Computer);
	FormParameters.Insert("Event",                 Data.Event);
	FormParameters.Insert("EventPresentation",    Data.EventPresentation);
	FormParameters.Insert("Comment",             Data.Comment);
	FormParameters.Insert("MetadataPresentation", Data.MetadataPresentation);
	FormParameters.Insert("Data",                  Data.Data);
	FormParameters.Insert("DataPresentation",     Data.DataPresentation);
	FormParameters.Insert("TransactionID",              Data.TransactionID);
	FormParameters.Insert("TransactionStatus",        Data.TransactionStatus);
	FormParameters.Insert("Session",                   Data.Session);
	FormParameters.Insert("ServerName",           Data.ServerName);
	FormParameters.Insert("Port",          Data.Port);
	FormParameters.Insert("SyncPort",   Data.SyncPort);
	
	If Data.Property("SessionDataSeparation") Then
		FormParameters.Insert("SessionDataSeparation", Data.SessionDataSeparation);
	EndIf;
	
	If ValueIsFilled(Data.DataAddress) Then
		FormParameters.Insert("DataAddress", Data.DataAddress);
	EndIf;
	
	Return FormParameters;
EndFunction

// For internal use only.
//
Procedure SetViewDateIntervalCompletion(Result, AdditionalParameters) Export
	
	EventLogFilter = AdditionalParameters.EventLogFilter;
	IntervalSet = False;
	
	If Result <> Undefined Then
		
		// Updating the current period
		DateInterval = Result;
		If DateInterval.StartDate = '00010101000000' Then
			EventLogFilter.Delete("StartDate");
		Else
			EventLogFilter.Insert("StartDate", DateInterval.StartDate);
		EndIf;
		
		If DateInterval.EndDate = '00010101000000' Then
			EventLogFilter.Delete("EndDate");
		Else
			EventLogFilter.Insert("EndDate", DateInterval.EndDate);
		EndIf;
		IntervalSet = True;
		
	EndIf;
	
	If AdditionalParameters.NotificationHandler <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.NotificationHandler, IntervalSet);
	EndIf;
	
EndProcedure

#EndRegion
