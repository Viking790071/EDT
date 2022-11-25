
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If SaaS.DataSeparationEnabled()
		AND SaaS.SeparatedDataUsageAvailable() Then
		
		CommonClientServer.MessageToUser(
			NStr("ru = 'Настройка подсистемы в разделенном режиме не поддерживается.'; en = 'Subsystem setup is not supported on the share mode.'; pl = 'Konfiguracja podsystemu nie jest obsługiwana w trybie podziału.';es_ES = 'Configuración del subsistema no está admitida en el modo de división.';es_CO = 'Configuración del subsistema no está admitida en el modo de división.';tr = 'Alt sistem yapılandırması bölünmüş modda desteklenmiyor.';it = 'L''impostazione sottosistema non è supportata nella modalità di condivisione.';de = 'Die Konfiguration des Subsystems wird im Split-Modus nicht unterstützt.'"),,,, Cancel);
		Return;
	EndIf;
	
	RefreshNodesStatesList();
	
	SetPrivilegedMode(True);
	
	Items.NodesStatesListEnableDisableSystemMessagesSendAndReceiveSchedule.Check =
		ScheduledJobsServer.ScheduledJobUsed(
			Metadata.ScheduledJobs.SendReceiveSystemMessages);;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = MessagesExchangeClient.EventNameSendAndReceiveMessageExecuted()
		OR EventName = MessagesExchangeClient.EndpointFormClosedEventName()
		OR EventName = MessagesExchangeClient.EndpointAddedEventName()
		OR EventName = MessagesExchangeClient.EventNameLeadingEndpointSet() Then
		
		RefreshMonitorData();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NodesStatesListChoice(Item, RowSelected, Field, StandardProcessing)
	
	ChangeEndpoint(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConnectEndpoint(Command)
	
	OpenForm("CommonForm.EndpointConnection",, ThisObject, 1);
	
EndProcedure

&AtClient
Procedure SetSubscriptions(Command)
	
	OpenForm("InformationRegister.RecipientSubscriptions.Form.ThisEndpointSubscriptionsSetup",, ThisObject);
	
EndProcedure

&AtClient
Procedure SendAndReceiveMessages(Command)
	
	MessagesExchangeClient.SendAndReceiveMessages();
	
EndProcedure

&AtClient
Procedure ChangeEndpoint(Command)
	
	CurrentData = Items.NodesStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(, CurrentData.InfobaseNode);
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	CurrentData = Items.NodesStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode, ThisObject, "DataExport");
	
EndProcedure

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	CurrentData = Items.NodesStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure SetSystemMessagesSendAndReceiveSchedule(Command)
	
	Dialog = New ScheduledJobDialog(GetSchedule());
	NotifyDescription = New NotifyDescription("SetSendReceiveSystemMessagesSchedule", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SetSendReceiveSystemMessagesSchedule(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		
		SetSchedule(Schedule);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableDisableSystemMessagesSendAndReceiveSchedule(Command)
	
	EnableDisableSystemMessagesSendAndReceiveScheduleAtServer();
	
EndProcedure

&AtClient
Procedure RefreshScreen(Command)
	
	RefreshMonitorData();
	
EndProcedure

&AtClient
Procedure More(Command)
	
	DetailsAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure EnableDisableSystemMessagesSendAndReceiveScheduleAtServer()
	
	SetPrivilegedMode(True);
	
	Items.NodesStatesListEnableDisableSystemMessagesSendAndReceiveSchedule.Check =
		NOT ScheduledJobsServer.ScheduledJobUsed(
			Metadata.ScheduledJobs.SendReceiveSystemMessages);
	
	ScheduledJobsServer.SetScheduledJobUsage(
		Metadata.ScheduledJobs.SendReceiveSystemMessages,
		Items.NodesStatesListEnableDisableSystemMessagesSendAndReceiveSchedule.Check);
	
EndProcedure

&AtServerNoContext
Function GetSchedule()
	
	SetPrivilegedMode(True);
	
	Return ScheduledJobsServer.JobSchedule(
		Metadata.ScheduledJobs.SendReceiveSystemMessages);
	
EndFunction

&AtServerNoContext
Procedure SetSchedule(Val Schedule)
	
	SetPrivilegedMode(True);
	
	ScheduledJobsServer.SetJobSchedule(
		Metadata.ScheduledJobs.SendReceiveSystemMessages,
		Schedule);
	
EndProcedure

&AtServer
Procedure RefreshNodesStatesList()
	
	NodesStateList.Clear();
	
	Array = New Array;
	Array.Add("MessageExchange");
	
	DataExchangeMonitor = DataExchangeServer.DataExchangeMonitorTable(Array, "Leading,Locked");
	
	// Updating data in the list of node states.
	For Each Setting In DataExchangeMonitor Do
		
		If Setting.Locked Then
			Continue;
		EndIf;
		
		FillPropertyValues(NodesStateList.Add(), Setting);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshMonitorData()
	
	NodesStatesListRowIndex = GetCurrentRowIndex("NodesStateList");
	
	// Updating monitor tables on the server.
	RefreshNodesStatesList();
	
	// Specifying a cursor position.
	ExecuteCursorPositioning("NodesStateList", NodesStatesListRowIndex);
	
EndProcedure

&AtClient
Function GetCurrentRowIndex(TableName)
	
	// Function return value.
	RowIndex = Undefined;
	
	// Placing a mouse pointer upon refreshing the dashboard.
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = ThisObject[TableName].IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
EndFunction

&AtClient
Procedure ExecuteCursorPositioning(TableName, RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Checking the mouse pointer position once the new data is received.
		If ThisObject[TableName].Count() <> 0 Then
			
			If RowIndex > ThisObject[TableName].Count() - 1 Then
				
				RowIndex = ThisObject[TableName].Count() - 1;
				
			EndIf;
			
			// placing the mouse pointer
			Items[TableName].CurrentRow = ThisObject[TableName][RowIndex].GetID();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DetailsAtServer()
	
	Items.DetailedNodesStatesList.Check = Not Items.DetailedNodesStatesList.Check;
	
	Items.NodesStatesListLastImportDate.Visible = Items.DetailedNodesStatesList.Check;
	Items.NodesStatesListLastExportDate.Visible = Items.DetailedNodesStatesList.Check;
	
EndProcedure

#EndRegion
