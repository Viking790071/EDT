
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	BeginOfPeriod = Parameters.BeginOfPeriod;
	EndOfPeriod  = Parameters.EndOfPeriod;
	ItemName   = Parameters.ItemName;
	
	If Not ValueIsFilled(BeginOfPeriod) Then
		BeginOfPeriod = ReportsClientServer.BeginOfReportPeriod(Parameters.MinimalPeriod, CurrentSessionDate());
	EndIf;
	
	If Not ValueIsFilled(EndOfPeriod) Then
		EndOfPeriod  = ReportsClientServer.EndOfReportPeriod(Parameters.MinimalPeriod, CurrentSessionDate());
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	If BeginOfPeriod > EndOfPeriod Then
		CommonClientServer.MessageToUser(NStr("en = 'Period start date is more than the period end date'; ru = 'Дата начала периода больше чем дата окончания периода';pl = 'Data rozpoczęcia okresu jest późniejsza niż data zakończenia okresu';es_ES = 'Fecha del inicio del período es mayor que la fecha del fin del período';es_CO = 'Fecha del inicio del período es mayor que la fecha del fin del período';tr = 'Dönem başlangıç tarihi bitiş tarihinden ileri';it = 'La data di inizio periodo è superiore alla data di fine periodo';de = 'Das Startdatum des Zeitraums ist größer als das Enddatum des Zeitraums'"), , "BeginOfPeriod");
		Return;
	EndIf;
	
	ChoiceResult = New Structure("BeginOfPeriod, EndOfPeriod, ItemName");
	FillPropertyValues(ChoiceResult, ThisObject);
	
	NotifyChoice(ChoiceResult);
EndProcedure

#EndRegion
