
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DaySchedule = Parameters.WorkSchedule;
	
	For Each IntervalDetails In DaySchedule Do
		FillPropertyValues(WorkSchedule.Add(), IntervalDetails);
	EndDo;
	WorkSchedule.Sort("BeginTime");
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("SelectAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WorkScheduleOnEditEnd(Item, NewRow, CancelEdit)
		
	If CancelEdit Then
		Return;
	EndIf;
	
	WorkSchedulesClientServer.RestoreCollectionRowOrderAfterEditing(WorkSchedule, "BeginTime", Item.CurrentData);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	SelectAndClose();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Modified = False;
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function DaySchedule()
	
	Cancel = False;
	
	DaySchedule = New Array;
	
	EndDay = Undefined;
	
	For Each ScheduleString In WorkSchedule Do
		RowIndex = WorkSchedule.IndexOf(ScheduleString);
		If ScheduleString.BeginTime > ScheduleString.EndTime 
			AND ValueIsFilled(ScheduleString.EndTime) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Время начала больше времени окончания'; en = 'Start time is greater than the end time'; pl = 'Czas rozpoczęcia jest późniejszy niż czas zakończenia.';es_ES = 'Hora inicial es mayor que la hora final.';es_CO = 'Hora inicial es mayor que la hora final.';tr = 'Başlangıç zamanı bitiş zamanından ileri';it = 'L''orario di avvio è maggiore di quello di fine';de = 'Startzeit ist größer als die Endzeit.'"), ,
				StringFunctionsClientServer.SubstituteParametersToString("WorkSchedule[%1].EndTime", RowIndex), ,
				Cancel);
		EndIf;
		If ScheduleString.BeginTime = ScheduleString.EndTime Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Длительность интервала не определена'; en = 'Interval duration is not defined'; pl = 'Nie określono czasu trwania interwału';es_ES = 'Duración del intervalo no está especificada';es_CO = 'Duración del intervalo no está especificada';tr = 'Aralık süresi belirtilmedi';it = 'La durata dell''intervallo non è definita';de = 'Die Dauer des Intervalls ist nicht angegeben'"), ,
				StringFunctionsClientServer.SubstituteParametersToString("WorkSchedule[%1].EndTime", RowIndex), ,
				Cancel);
		EndIf;
		If EndDay <> Undefined Then
			If EndDay > ScheduleString.BeginTime 
				Or Not ValueIsFilled(EndDay) Then
				CommonClientServer.MessageToUser(
					NStr("ru = 'Обнаружены пересекающиеся интервалы'; en = 'Overlapping intervals are detected'; pl = 'Wykryto nakładające się interwały';es_ES = 'Intervalos de superposición se han detectado';es_CO = 'Intervalos de superposición se han detectado';tr = 'Çakışan aralıklar tespit edildi';it = 'Gli intervalli sovrapposti vengono rilevati';de = 'Überlappende Intervalle werden erkannt'"), ,
					StringFunctionsClientServer.SubstituteParametersToString("WorkSchedule[%1].BeginTime", RowIndex), ,
					Cancel);
			EndIf;
		EndIf;
		EndDay = ScheduleString.EndTime;
		DaySchedule.Add(New Structure("BeginTime, EndTime", ScheduleString.BeginTime, ScheduleString.EndTime));
	EndDo;
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	Return DaySchedule;
	
EndFunction

&AtClient
Procedure SelectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	DaySchedule = DaySchedule();
	If DaySchedule = Undefined Then
		Return;
	EndIf;
	
	Modified = False;
	NotifyChoice(New Structure("WorkSchedule", DaySchedule));
	
EndProcedure

#EndRegion
