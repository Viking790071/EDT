
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	EndpointConnectionEventLogEvent = MessageExchangeInternal.EndpointConnectionEventLogEvent();
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("ConnectAndClose", ThisObject);
	WarningText = NStr("ru = 'Отменить подключение конечной точки?'; en = 'Do you want to cancel the endpoint connection?'; pl = 'Czy chcesz przerwać połączenie z punktem końcowym?';es_ES = '¿Quiere cancelar la conexión para el punto extremo?';es_CO = '¿Quiere cancelar la conexión para el punto extremo?';tr = 'Uç noktanın bağlantısını iptal etmek istiyor musunuz?';it = 'Annullare la connessione endpoint?';de = 'Do you want to cancel connection to the endpoint?'");
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit, WarningText);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConnectEndpoint(Command)
	
	ConnectAndClose();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ConnectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	Cancel = False;
	FillError = False;
	
	ConnectEndpointAtServer(Cancel, FillError);
	
	If FillError Then
		Return;
	EndIf;
	
	If Cancel Then
		
		NString = NStr("ru = 'При подключении конечной точки возникли ошибки.
		|Перейти в журнал регистрации?'; 
		|en = 'Errors occurred during the endpoint connection. 
		|Go to the event log?'; 
		|pl = 'Podczas łączenia się z punktem końcowym wystąpiły błędy.
		|Czy chcesz otworzyć dziennik wydarzeń?';
		|es_ES = 'No había errores al conectar para el punto extremo.
		|¿Quiere abrir el registro de eventos?';
		|es_CO = 'No había errores al conectar para el punto extremo.
		|¿Quiere abrir el registro de eventos?';
		|tr = 'Uç noktasına bağlanırken hatalar oluştu.
		| Olay günlüğünü açmak istiyor musunuz?';
		|it = 'Si è verificato un errore durante la connessione di endpoint. 
		|Andare al registro degli eventi?';
		|de = 'Beim Verbinden mit dem Endpunkt sind Fehler aufgetreten.
		|Möchten Sie das Ereignisprotokoll öffnen?'");
		NotifyDescription = New NotifyDescription("OpenEventLog", ThisObject);
		ShowQueryBox(NotifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	Notify(MessagesExchangeClient.EndpointAddedEventName());
	
	ShowUserNotification(,,NStr("ru = 'Подключение конечной точки успешно завершено.'; en = 'The endpoint is connected.'; pl = 'Podłączenie punktu końcowego zakończone pomyślnie.';es_ES = 'Conexión del punto extremo se ha finalizado con éxito.';es_CO = 'Conexión del punto extremo se ha finalizado con éxito.';tr = 'Uç noktanın bağlantısı başarıyla tamamlandı.';it = 'Endpoint connesso.';de = 'Verbindung des Endpunktes erfolgreich abgeschlossen.'"));
	
	Modified = False;
	
	Close();
	
EndProcedure

&AtClient
Procedure OpenEventLog(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", EndpointConnectionEventLogEvent);
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ConnectEndpointAtServer(Cancel, FillError)
	
	If Not CheckFilling() Then
		FillError = True;
		Return;
	EndIf;
	
	SenderConnectionSettings = DataExchangeServer.WSParameterStructure();
	SenderConnectionSettings.WSWebServiceURL   = SenderSettingsWSURL;
	SenderConnectionSettings.WSUsername = SenderSettingsWSUsername;
	SenderConnectionSettings.WSPassword          = SenderSettingsWSPassword;
	
	RecipientConnectionSettings = DataExchangeServer.WSParameterStructure();
	RecipientConnectionSettings.WSWebServiceURL   = RecipientSettingsWSURL;
	RecipientConnectionSettings.WSUsername = RecipientSettingsWSUsername;
	RecipientConnectionSettings.WSPassword          = RecipientSettingsWSPassword;
	
	MessageExchange.ConnectEndpoint(
		Cancel,
		SenderConnectionSettings,
		RecipientConnectionSettings);
	
EndProcedure

#EndRegion
