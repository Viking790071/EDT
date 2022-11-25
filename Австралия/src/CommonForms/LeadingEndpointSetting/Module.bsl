
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;

	LeadingEndpointSettingEventLogMessage = MessageExchangeInternal.LeadingEndpointSettingEventLogMessage();
	
	Endpoint = Parameters.Endpoint;
	
	// Reading the connection setting values.
	FillPropertyValues(ThisObject, InformationRegisters.MessageExchangeTransportSettings.TransportSettingsWS(Endpoint));
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Установка ведущей конечной точки для ""%1""'; en = 'Setting the leading endpoint for %1'; pl = 'Ustaw wiodący punkt końcowy dla ""%1""';es_ES = 'Establecer el punto extremo principal para ""%1""';es_CO = 'Establecer el punto extremo principal para ""%1""';tr = '""%1"" için başlangıç uç noktasını ayarlayın';it = 'Impostazione del endpoint principale per %1';de = 'Setze den führenden Endpunkt für ""%1""'"),
		Common.ObjectAttributeValue(Endpoint, "Description"));
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	WarningText = NStr("ru = 'Отменить выполнение операции?'; en = 'Do you want to cancel the operation?'; pl = 'Czy chcesz anulować operację?';es_ES = '¿Quiere cancelar la operación?';es_CO = '¿Quiere cancelar la operación?';tr = 'İşlemi iptal etmek istiyor musunuz?';it = 'Volete annulla l''operazione?';de = 'Möchten Sie die Operation abbrechen?'");
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Apply(Command)
	
	Cancel = False;
	FillError = False;
	
	SetLeadingEndpointAtServer(Cancel, FillError);
	
	If FillError Then
		Return;
	EndIf;
	
	If Cancel Then
		
		NString = NStr("ru = 'При установке ведущей конечной точки возникли ошибки.
		|Перейти в журнал регистрации?'; 
		|en = 'Errors occurred when trying to establish the leading endpoint.
		|Go to the event log?'; 
		|pl = 'Wystąpiły błędy podczas ustawiania wiodącego punktu końcowego.
		|Czy chcesz otworzyć dziennik wydarzeń?';
		|es_ES = 'Han ocurrido errores al configurar el punto extremo principal.
		|¿Quiere abrir el registro de eventos?';
		|es_CO = 'Han ocurrido errores al configurar el punto extremo principal.
		|¿Quiere abrir el registro de eventos?';
		|tr = 'Başlangıç uç noktası ayarlanırken hata oluştu.
		|Olay günlüğünü açmak istiyor musunuz?';
		|it = 'Si sono verificati degli errore durante il tentativo di impostazione dell''endpoint principale.
		|Andare al registro degli eventi?';
		|de = 'Beim Festlegen des führenden Endpunkts sind Fehler aufgetreten.
		|Möchten Sie das Ereignisprotokoll öffnen?'");
		NotifyDescription = New NotifyDescription("OpenEventLog", ThisObject);
		ShowQueryBox(NotifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	Notify(MessagesExchangeClient.EventNameLeadingEndpointSet());
	
	ShowUserNotification(,, NStr("ru = 'Установка ведущей конечной точки успешно завершена.'; en = 'The leading endpoint is set.'; pl = 'Główny punkt końcowy został ustawiony pomyślnie.';es_ES = 'Punto extremo principal se ha establecido con éxito.';es_CO = 'Punto extremo principal se ha establecido con éxito.';tr = 'Başlangıç uç noktası başarı ile ayarlandı.';it = 'Endpoint principale impostato.';de = 'Der führende Endpunkt wird erfolgreich festgelegt.'"));
	
	ForceCloseForm = True;
	
	Close();
	
EndProcedure

&AtClient
Procedure OpenEventLog(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", LeadingEndpointSettingEventLogMessage);
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetLeadingEndpointAtServer(Cancel, FillError)
	
	If Not CheckFilling() Then
		FillError = True;
		Return;
	EndIf;
	
	WSConnectionSettings = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(WSConnectionSettings, ThisObject);
	
	MessageExchangeInternal.SetLeadingEndpointAtSender(Cancel, WSConnectionSettings, Endpoint);
	
EndProcedure

#EndRegion
