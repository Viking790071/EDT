
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataStructure = GetFromTempStorage(Parameters.DataAddress);
	
	DataStructure.Property("ReadOnly",						ReadOnly);
	DataStructure.Property("UserDefinedStartDate",			UserDefinedStartDate);
	DataStructure.Property("UserDefinedEndDate",			UserDefinedEndDate);
	DataStructure.Property("UserDefinedBusinessCalendar",	UserDefinedBusinessCalendar);
	DataStructure.Property("UserDefinedDateType",			UserDefinedDateType);
	DataStructure.Property("UserDefinedDayOf",				UserDefinedDayOf);
	DataStructure.Property("UserDefinedCalculateFrom",		UserDefinedCalculateFrom);
	DataStructure.Property("IsDocumentsGenerated",			IsDocumentsGenerated);
	
	SetLineNumber(DataStructure.UserDefinedSchedule);
	
	UserDefinedSchedule.Load(DataStructure.UserDefinedSchedule);
	
	SetVisibleAndEnabled();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StartDateStartChoice(Item, ChoiceData, StandardProcessing)
	
	OldValue = UserDefinedStartDate;
	
EndProcedure

&AtClient
Procedure StartDateOnChange(Item)
	
	If UserDefinedEndDate < UserDefinedStartDate Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The start date is later than the end date. Please correct the dates.'; ru = 'Дата начала не может быть больше даты окончания.';pl = 'Data rozpoczęcia nie może być późniejsza niż data zakończenia. Skoryguj daty.';es_ES = 'La fecha del inicio es posterior a la fecha del fin. Por favor, corrija las fechas.';es_CO = 'La fecha del inicio es posterior a la fecha del fin. Por favor, corrija las fechas.';tr = 'Başlangıç tarihi bitiş tarihinden ileri. Lütfen, tarihleri düzeltin.';it = 'La data di inizio è successiva alla data di fine. Correggere le date.';de = 'Das Startdatum liegt nach dem Enddatum. Bitte korrigieren Sie die Daten.'"));
		Return;
		
	EndIf;
	
	If OldValue <> UserDefinedStartDate 
		And UserDefinedSchedule.Count() > 0 Then
		
		ShowQueryBoxAttributesOnChange("UserDefinedStartDate");
		
		Return;
		
	EndIf;
	
	OldValue = Undefined;
	
EndProcedure

&AtClient
Procedure StartDateTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	NewDate = GetDateFromStringClient(Item.EditText);
	
	If NewDate > UserDefinedEndDate Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'The start date is later than the end date. Please correct the dates.'; ru = 'Дата начала не может быть больше даты окончания.';pl = 'Data rozpoczęcia nie może być późniejsza niż data zakończenia. Skoryguj daty.';es_ES = 'La fecha del inicio es posterior a la fecha del fin. Por favor, corrija las fechas.';es_CO = 'La fecha del inicio es posterior a la fecha del fin. Por favor, corrija las fechas.';tr = 'Başlangıç tarihi bitiş tarihinden ileri. Lütfen, tarihleri düzeltin.';it = 'La data di inizio è successiva alla data di fine. Correggere le date.';de = 'Das Startdatum liegt nach dem Enddatum. Bitte korrigieren Sie die Daten.'"),
			,
			"UserDefinedStartDate");
		
		Return;
		
	ElsIf NewDate = Date(1, 1, 1) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'The start date is required.'; ru = 'Требуется указать дату начала.';pl = 'Wymagana jest data rozpoczęcia.';es_ES = 'Se requiere la fecha de inicio.';es_CO = 'Se requiere la fecha de inicio.';tr = 'Başlangıç tarihi gerekli.';it = 'È richiesta la data di inizio.';de = 'Das Startdatum ist erforderlich.'"),
			,
			"UserDefinedStartDate");
		
		Return;
		
	EndIf;
	
	OldValue = UserDefinedStartDate;
	UserDefinedStartDate = NewDate;
	
EndProcedure

&AtClient
Procedure EndDateStartChoice(Item, ChoiceData, StandardProcessing)
	
	OldValue = UserDefinedEndDate;
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	
	If UserDefinedEndDate < UserDefinedStartDate Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The end date is earlier than the start date. Please correct the dates.'; ru = 'Дата окончания не может быть меньше даты начала.';pl = 'Data zakończenia jest wcześniejsza niż data rozpoczęcia. Skoryguj daty.';es_ES = 'La fecha final es anterior a la fecha del inicio. Por favor, corrija las fechas.';es_CO = 'La fecha final es anterior a la fecha del inicio. Por favor, corrija las fechas.';tr = 'Bitiş tarihi başlangıç tarihinden önce. Lütfen, tarihleri düzeltin.';it = 'La data di fine è precedente alla data di inizio. Correggere le date.';de = 'Das Enddatum liegt vor dem Startdatum. Bitte korrigieren Sie die Daten.'"));
		Return;
		
	EndIf;
	
	If OldValue <> UserDefinedEndDate 
		And UserDefinedSchedule.Count() > 0 Then
		
		ShowQueryBoxAttributesOnChange("UserDefinedEndDate");
		
		Return;
		
	EndIf;
	
	OldValue = Undefined;
	
EndProcedure

&AtClient
Procedure EndDateTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	NewDate = GetDateFromStringClient(Item.EditText);
	
	If NewDate < UserDefinedStartDate Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'The end date is earlier than the start date. Please correct the dates.'; ru = 'Дата окончания не может быть меньше даты начала.';pl = 'Data zakończenia jest wcześniejsza niż data rozpoczęcia. Skoryguj daty.';es_ES = 'La fecha final es anterior a la fecha del inicio. Por favor, corrija las fechas.';es_CO = 'La fecha final es anterior a la fecha del inicio. Por favor, corrija las fechas.';tr = 'Bitiş tarihi başlangıç tarihinden önce. Lütfen, tarihleri düzeltin.';it = 'La data di fine è precedente alla data di inizio. Correggere le date.';de = 'Das Enddatum liegt vor dem Startdatum. Bitte korrigieren Sie die Daten.'")
			,
			"UserDefinedEndDate");
		
		Return;
		
	ElsIf NewDate = Date(1, 1, 1) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'The end date is required.'; ru = 'Требуется указать дату окончания.';pl = 'Wymagana jest data zakończenia.';es_ES = 'Se requiere la fecha final.';es_CO = 'Se requiere la fecha final.';tr = 'Bitiş tarihi gerekli.';it = 'È richiesta la data di fine.';de = 'Das Enddatum ist erforderlich.'"),
			,
			"UserDefinedEndDate");
		
		Return;
		
	EndIf;
	
	OldValue = UserDefinedEndDate;
	UserDefinedEndDate = NewDate;
	
EndProcedure

&AtClient
Procedure BusinessCalendarStartChoice(Item, ChoiceData, StandardProcessing)
	
	OldValue = UserDefinedBusinessCalendar;
	
EndProcedure

&AtClient
Procedure BusinessCalendarOnChange(Item)
	
	If OldValue <> UserDefinedBusinessCalendar 
		And UserDefinedSchedule.Count() > 0 Then
		
		ShowQueryBoxAttributesOnChange("UserDefinedBusinessCalendar");
		
		Return;
		
	EndIf;
	
	OldValue = Undefined;
	
EndProcedure

&AtClient
Procedure DayOfStartChoice(Item, ChoiceData, StandardProcessing)
	
	OldValue = UserDefinedDayOf;
	
EndProcedure

&AtClient
Procedure DayOfOnChange(Item)
	
	TextMessage = NStr("en = 'The range of day numbers is from 1 to 31. Specify a number from this range.'; ru = 'Диапазон чисел дней - от 1 до 31. Укажите число из этого диапазона.';pl = 'Zakres dat wynosi od 1 do 31. Określ liczbę z tego zakresu.';es_ES = 'El rango de números de días es de 1 a 31. Especifique un número de este rango.';es_CO = 'El rango de números de días es de 1 a 31. Especifique un número de este rango.';tr = 'Gün sayısı 1 ile 31 arasında olabilir. Bu aralıkta bir sayı girin.';it = 'L''intervallo di numeri di giorni è da 1 a 31. Specificare un numero in questo intervallo.';de = 'Der Bereich der Tagesnummern liegt zwischen 1 und 31. Geben Sie eine Zahl aus diesem Bereich an.'");
	
	If UserDefinedDayOf > 31 Then
		
		CommonClientServer.MessageToUser(TextMessage);
		
		UserDefinedDayOf = 31;
		
	ElsIf UserDefinedDayOf = 0 Then
		
		CommonClientServer.MessageToUser(TextMessage);
		
		UserDefinedDayOf = 1;
		
	EndIf;
	
	If OldValue <> UserDefinedDayOf 
		And UserDefinedSchedule.Count() > 0 Then
		
		ShowQueryBoxAttributesOnChange("UserDefinedDayOf");
		
		Return;
		
	EndIf;
	
	OldValue = Undefined;
	
EndProcedure

&AtClient
Procedure DateTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	OldValue = UserDefinedDateType;
	
EndProcedure

&AtClient
Procedure DateTypeOnChange(Item)
	
	If OldValue <> UserDefinedDateType 
		And UserDefinedSchedule.Count() > 0 Then
		
		ShowQueryBoxAttributesOnChange("UserDefinedDateType");
		
		Return;
		
	EndIf;
	
	OldValue = Undefined;
	
EndProcedure

&AtClient
Procedure CalculateFromStartChoice(Item, ChoiceData, StandardProcessing)
	
	OldValue = UserDefinedCalculateFrom;
	
EndProcedure

&AtClient
Procedure CalculateFromOnChange(Item)
	
	If OldValue <> UserDefinedCalculateFrom 
		And UserDefinedSchedule.Count() > 0 Then
		
		ShowQueryBoxAttributesOnChange("UserDefinedCalculateFrom");
		
		Return;
		
	EndIf;
	
	OldValue = Undefined;
	
EndProcedure

&AtClient
Procedure ParametersUserDefinedScheduleChanged(Result, UserDefinedParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		If IsErrorsAttributesUserDefinedSchedule() Then
			
			Return;
			
		EndIf;
		
		FillAtServer();
		
		CheckValueTableUserDefinedSchedule();
		
	Else 
		
		ThisObject[UserDefinedParameters.Item] = OldValue;
		
	EndIf;
	
	OldValue = Undefined;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	If ReadOnly Then
		Modified = False;
		Close();
	Else
		PutCustomScheduleDataInStorage();
		ClosingStructure = New Structure;
		ClosingStructure.Insert("DataAddress", DataAddress); 
		Close(ClosingStructure);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetPeriod(Command)
	
	If UserDefinedSchedule.Count() > 0
		And IsErrorsAttributesUserDefinedSchedule() Then
		
		Return;
		
	EndIf;
	
	OldValue	= UserDefinedStartDate;
	OldValue_2	= UserDefinedEndDate;
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate	= UserDefinedStartDate;
	Dialog.Period.EndDate	= UserDefinedEndDate;
	
	Dialog.Show(New NotifyDescription("SetPeriodCompleted", ThisObject));
	
EndProcedure

&AtClient
Procedure SetPeriodCompleted(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		UserDefinedStartDate = Result.StartDate;
		UserDefinedEndDate = Result.EndDate;
		
		If ((OldValue <> UserDefinedStartDate
			And OldValue <> Date(1, 1, 1))
			Or (OldValue_2 <> UserDefinedEndDate 
			And OldValue_2 <> Date(1, 1, 1)))
			And UserDefinedSchedule.Count() > 0 Then
			
			Notification = New NotifyDescription("PeriodUserDefinedScheduleChanged", ThisObject);
			
			If IsDocumentsGenerated Then
				TextQuestion = NStr("en = 'Documents have already been generated according to this schedule. 
					|Changing the schedule settings can cause inconsistencies in the Generated documents summary report. 
					|Do you want to continiue?'; 
					|ru = 'Документы уже созданы в соответствии с этим графиком. 
					|Изменение настроек графика может привести к несоответствиям в сводном отчете Созданные документы. 
					|Продолжить?';
					|pl = 'Dokumenty już zostały wygenerowane zgodnie z tym harmonogramem. 
					|Zmiana ustawień harmonogramu może doprowadzić do niespójności w wygenerowanym raporcie zbiorczym dokumentów. 
					|Czy chcesz kontynuować?';
					|es_ES = 'Ya se han generado los documentos de acuerdo con este horario. 
					|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
					|¿Quiere continuar?';
					|es_CO = 'Ya se han generado los documentos de acuerdo con este horario. 
					|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
					|¿Quiere continuar?';
					|tr = 'Bu programa göre belgeler oluşturuldu. 
					|Program ayarlarını değiştirmek oluşturulmuş belgeler özeti raporunda tutarsızlıklara yol açabilir. 
					|Devam etmek istiyor musunuz?';
					|it = 'I documenti sono stati già generati in base a questo programma. 
					|Modificare le impostazioni di programma può causare inconsistenze nel report del Riepilogo documenti generati. 
					|Continuare?';
					|de = 'Nach diesem Zeitplan wurden bereits Dokumente generiert. 
					|Das Ändern der Zeitplaneinstellungen kann zu Inkonsistenzen im Zusammenfassungsbericht „Generierte Dokumente“ führen. 
					|Möchten Sie fortsetzen?'");
			Else
				TextQuestion = NStr("en = 'The schedule will be updated. Do you want to continue?'; ru = 'График будет обновлен. Продолжить?';pl = 'Harmonogram zostanie zaktualizowany. Czy chcesz kontynuować?';es_ES = 'El horario se actualizará. ¿Quiere continuar?';es_CO = 'El horario se actualizará. ¿Quiere continuar?';tr = 'Program güncellenecek. Devam etmek istiyor musunuz?';it = 'Il programma verrà aggiornato. Continuare?';de = 'Die Zeitplan wird aktualisiert. Möchten Sie fortsetzen?'");
			EndIf;
		
			Mode = QuestionDialogMode.YesNo;
			ShowQueryBox(Notification, TextQuestion, Mode, 0);
			
			Return;
			
		EndIf;
		
	EndIf;
	
	OldValue	= Undefined;
	OldValue_2	= Undefined;
	
EndProcedure

&AtClient
Procedure PeriodUserDefinedScheduleChanged(Result, UserDefinedParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		FillAtServer();
		
		CheckValueTableUserDefinedSchedule();
		
	Else 
		
		UserDefinedStartDate	= OldValue;
		UserDefinedEndDate		= OldValue_2;
		
	EndIf;
	
	OldValue	= Undefined;
	OldValue_2	= Undefined;
	
EndProcedure

&AtClient
Procedure FillUserDefinedSchedule(Command)
	
	If IsErrorsAttributesUserDefinedSchedule() Then
		
		Return;
		
	EndIf;
	
	If IsDocumentsGenerated 
		Or UserDefinedSchedule.Count() > 0 Then
		
		Notification = New NotifyDescription("FillUserDefinedScheduleEnd", ThisObject);
		
		If IsDocumentsGenerated Then
			
			TextQuestion = NStr("en = 'Documents have already been generated according to this schedule. 
				|Changing the schedule settings can cause inconsistencies in the Generated documents summary report. 
				|Do you want to continiue?'; 
				|ru = 'Документы уже созданы в соответствии с этим графиком. 
				|Изменение настроек графика может привести к несоответствиям в сводном отчете Созданные документы. 
				|Продолжить?';
				|pl = 'Dokumenty już zostały wygenerowane zgodnie z tym harmonogramem. 
				|Zmiana ustawień harmonogramu może doprowadzić do niespójności w wygenerowanym raporcie zbiorczym dokumentów. 
				|Czy chcesz kontynuować?';
				|es_ES = 'Ya se han generado los documentos de acuerdo con este horario. 
				|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
				|¿Quiere continuar?';
				|es_CO = 'Ya se han generado los documentos de acuerdo con este horario. 
				|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
				|¿Quiere continuar?';
				|tr = 'Bu programa göre belgeler oluşturuldu. 
				|Program ayarlarını değiştirmek oluşturulmuş belgeler özeti raporunda tutarsızlıklara yol açabilir. 
				|Devam etmek istiyor musunuz?';
				|it = 'I documenti sono stati già generati in base a questo programma. 
				|Modificare le impostazioni di programma può causare inconsistenze nel report del Riepilogo documenti generati. 
				|Continuare?';
				|de = 'Nach diesem Zeitplan wurden bereits Dokumente generiert. 
				|Das Ändern der Zeitplaneinstellungen kann zu Inkonsistenzen im Zusammenfassungsbericht „Generierte Dokumente“ führen. 
				|Möchten Sie fortsetzen?'");
			
		Else
			
			TextQuestion = NStr("en = 'The schedule will be updated. Do you want to continue?'; ru = 'График будет обновлен. Продолжить?';pl = 'Harmonogram zostanie zaktualizowany. Czy chcesz kontynuować?';es_ES = 'El horario se actualizará. ¿Quiere continuar?';es_CO = 'El horario se actualizará. ¿Quiere continuar?';tr = 'Program güncellenecek. Devam etmek istiyor musunuz?';it = 'Il programma verrà aggiornato. Continuare?';de = 'Die Zeitplan wird aktualisiert. Möchten Sie fortsetzen?'");
			
		EndIf;
		
		Mode = QuestionDialogMode.YesNo;
		ShowQueryBox(Notification, TextQuestion, Mode, 0);
		
		Return;
	
	EndIf;
	
	FillAtServer();
	
	CheckValueTableUserDefinedSchedule();
	
EndProcedure

&AtClient
Procedure FillUserDefinedScheduleEnd(Result, UserDefinedParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		FillAtServer();
		
		CheckValueTableUserDefinedSchedule();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region UserDefinedScheduleFormTableItemsEventHandlers

&AtClient
Procedure UserDefinedScheduleOnChange(Item)
	
	UserDefinedSchedule.Sort("PlannedDate");
	
	SetLineNumberClient(UserDefinedSchedule);
	
EndProcedure

&AtClient
Procedure UserDefinedScheduleOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
	
		Item.CurrentData.PlannedDate = GetCurrentSessionDate();
	
	EndIf;
	
EndProcedure

&AtClient
Procedure UserDefinedScheduleOnEditEnd(Item, NewRow, CancelEdit)
	
	UserDefinedSchedule.Sort("PlannedDate");
	
	SetLineNumberClient(UserDefinedSchedule);
	
EndProcedure

&AtClient
Procedure UserDefinedScheduleBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Not ValueIsFilled(UserDefinedStartDate) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The period start date is required.'; ru = 'Требуется указать дату начала периода.';pl = 'Wymagana jest data rozpoczęcia okresu.';es_ES = 'Se requiere la fecha de inicio del período.';es_CO = 'Se requiere la fecha de inicio del período.';tr = 'Dönem başlangıç tarihi gerekli.';it = 'È richiesta la data di inizio del periodo.';de = 'Das Startdatum des Zeitraums ist erforderlich.'"));
		Cancel = True;
		
	EndIf;
	
	If Not ValueIsFilled(UserDefinedEndDate) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The period end date is required.'; ru = 'Требуется указать дату окончания периода.';pl = 'Wymagana jest data zakończenia okresu.';es_ES = 'Se requiere la fecha final del período.';es_CO = 'Se requiere la fecha final del período.';tr = 'Dönem sonu tarihi gerekli.';it = 'È richiesta la data di fine periodo.';de = 'Das Enddatum des Zeitraums ist erforderlich.'"));
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UserDefinedScheduleBeforeDeleteRow(Item, Cancel)
	
	ValueToDelete = Item.CurrentData.PlannedDate;
	
	If IsDocumentsGenerated 
		And ValueToDelete < GetCurrentSessionDate() Then
		
		Cancel = True;
		
		UserDefinedParameters = New Structure("Item", Item.CurrentData);
		
		Notification = New NotifyDescription("UserDefinedScheduleBeforeDeleteRowEnd", ThisObject, UserDefinedParameters);
		
		TextQuestion = NStr("en = 'Documents have already been generated according to this schedule. 
			|Changing the schedule settings can cause inconsistencies in the Generated documents summary report. 
			|Do you want to continiue?'; 
			|ru = 'Документы уже созданы в соответствии с этим графиком. 
			|Изменение настроек графика может привести к несоответствиям в сводном отчете Созданные документы. 
			|Продолжить?';
			|pl = 'Dokumenty już zostały wygenerowane zgodnie z tym harmonogramem. 
			|Zmiana ustawień harmonogramu może doprowadzić do niespójności w wygenerowanym raporcie zbiorczym dokumentów. 
			|Czy chcesz kontynuować?';
			|es_ES = 'Ya se han generado los documentos de acuerdo con este horario. 
			|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
			|¿Quiere continuar?';
			|es_CO = 'Ya se han generado los documentos de acuerdo con este horario. 
			|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
			|¿Quiere continuar?';
			|tr = 'Bu programa göre belgeler oluşturuldu. 
			|Program ayarlarını değiştirmek oluşturulmuş belgeler özeti raporunda tutarsızlıklara yol açabilir. 
			|Devam etmek istiyor musunuz?';
			|it = 'I documenti sono stati già generati in base a questo programma. 
			|Modificare le impostazioni di programma può causare inconsistenze nel report del Riepilogo documenti generati. 
			|Continuare?';
			|de = 'Nach diesem Zeitplan wurden bereits Dokumente generiert. 
			|Das Ändern der Zeitplaneinstellungen kann zu Inkonsistenzen im Zusammenfassungsbericht „Generierte Dokumente“ führen. 
			|Möchten Sie fortsetzen?'");
		
		Mode = QuestionDialogMode.YesNo;
		ShowQueryBox(Notification, TextQuestion, Mode, 0);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UserDefinedScheduleBeforeDeleteRowEnd(Result, UserDefinedParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		LineToDelete = UserDefinedParameters["Item"];
		
		UserDefinedSchedule.Delete(LineToDelete);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UserDefinedSchedulePlannedDateStartChoice(Item, ChoiceData, StandardProcessing)
	
	OldValue = Item.Parent.CurrentData.PlannedDate;
	
EndProcedure

&AtClient
Procedure UserDefinedSchedulePlannedDateOnChange(Item)
	
	NewValue = Item.Parent.CurrentData.PlannedDate;
	
	If NewValue < GetCurrentSessionDate()
		Or (OldValue <> Date(1, 1, 1)
		And OldValue < GetCurrentSessionDate()) Then
		
		UserDefinedParameters = New Structure("Item", Item);
		
		Notification = New NotifyDescription("UserDefinedSchedulePlannedDateOnChangeEnd", ThisObject, UserDefinedParameters);
		
		If IsDocumentsGenerated Then
		
			TextQuestion = NStr("en = 'Documents have already been generated according to this schedule. 
				|Changing the schedule settings can cause inconsistencies in the Generated documents summary report. 
				|Do you want to continiue?'; 
				|ru = 'Документы уже созданы в соответствии с этим графиком. 
				|Изменение настроек графика может привести к несоответствиям в сводном отчете Созданные документы. 
				|Продолжить?';
				|pl = 'Dokumenty już zostały wygenerowane zgodnie z tym harmonogramem. 
				|Zmiana ustawień harmonogramu może doprowadzić do niespójności w wygenerowanym raporcie zbiorczym dokumentów. 
				|Czy chcesz kontynuować?';
				|es_ES = 'Ya se han generado los documentos de acuerdo con este horario. 
				|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
				|¿Quiere continuar?';
				|es_CO = 'Ya se han generado los documentos de acuerdo con este horario. 
				|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
				|¿Quiere continuar?';
				|tr = 'Bu programa göre belgeler oluşturuldu. 
				|Program ayarlarını değiştirmek oluşturulmuş belgeler özeti raporunda tutarsızlıklara yol açabilir. 
				|Devam etmek istiyor musunuz?';
				|it = 'I documenti sono stati già generati in base a questo programma. 
				|Modificare le impostazioni di programma può causare inconsistenze nel report del Riepilogo documenti generati. 
				|Continuare?';
				|de = 'Nach diesem Zeitplan wurden bereits Dokumente generiert. 
				|Das Ändern der Zeitplaneinstellungen kann zu Inkonsistenzen im Zusammenfassungsbericht „Generierte Dokumente“ führen. 
				|Möchten Sie fortsetzen?'");
			
		Else
		
			TextQuestion = NStr("en = 'The schedule will be updated. Do you want to continue?'; ru = 'График будет обновлен. Продолжить?';pl = 'Harmonogram zostanie zaktualizowany. Czy chcesz kontynuować?';es_ES = 'El horario se actualizará. ¿Quiere continuar?';es_CO = 'El horario se actualizará. ¿Quiere continuar?';tr = 'Program güncellenecek. Devam etmek istiyor musunuz?';it = 'Il programma verrà aggiornato. Continuare?';de = 'Der Zeitplan wird aktualisiert. Möchten Sie fortsetzen?'");
		
		EndIf;
		
		Mode = QuestionDialogMode.YesNo;
		ShowQueryBox(Notification, TextQuestion, Mode, 0);
		
		Return;
	
	ElsIf NewValue < UserDefinedStartDate 
		Or NewValue > UserDefinedEndDate Then
		
		TextMessage = NStr("en = 'The specified date is not within the custom schedule period.'; ru = 'Указанная дата не находится в пределах периода пользовательского графика.';pl = 'Określona data nie jest w niestandardowym okresie harmonogramu.';es_ES = 'La fecha especificada no está incluida en el período del horario personalizado.';es_CO = 'La fecha especificada no está incluida en el período del horario personalizado.';tr = 'Belirtilen tarih özel program dönemi içinde değil.';it = 'La data specificata non rientra nel periodo di programma personalizzato.';de = 'Das angegebene Datum liegt nicht innerhalb des Zeitraums des benutzerdefinierten Zeitplans.'");
		CommonClientServer.MessageToUser(TextMessage);
		
		NewValue = UserDefinedEndDate;
		Item.Parent.CurrentData.PlannedDate = NewValue;
		
	ElsIf NewValue = Date(1, 1, 1) 
		And OldValue <> Date(1, 1, 1) Then
		
		Item.Parent.CurrentData.PlannedDate = OldValue;
		
	EndIf;
	
	OldValue = Undefined;
	
	UserDefinedSchedule.Sort("PlannedDate");
	
	SetLineNumberClient(UserDefinedSchedule);
	
EndProcedure

&AtClient
Procedure UserDefinedSchedulePlannedDateOnChangeEnd(Result, UserDefinedParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		NewValue = UserDefinedParameters["Item"].Parent.CurrentData.PlannedDate;
		
		If NewValue < UserDefinedStartDate 
			Or NewValue > UserDefinedEndDate Then
			
			TextMessage = NStr("en = 'The specified date is not within the custom schedule period.'; ru = 'Указанная дата не находится в пределах периода пользовательского графика.';pl = 'Określona data nie jest w niestandardowym okresie harmonogramu.';es_ES = 'La fecha especificada no está incluida en el período del horario personalizado.';es_CO = 'La fecha especificada no está incluida en el período del horario personalizado.';tr = 'Belirtilen tarih özel program dönemi içinde değil.';it = 'La data specificata non rientra nel periodo di programma personalizzato.';de = 'Das angegebene Datum liegt nicht innerhalb des Zeitraums des benutzerdefinierten Zeitplans.'");
			CommonClientServer.MessageToUser(TextMessage);
			
			NewValue = UserDefinedEndDate;
			UserDefinedParameters["Item"].Parent.CurrentData.PlannedDate = NewValue;
			
		ElsIf NewValue = Date(1, 1, 1) 
			And OldValue <> Date(1, 1, 1) Then
			
			UserDefinedParameters["Item"].Parent.CurrentData.PlannedDate = OldValue;
			
		ElsIf NewValue = Date(1, 1, 1) Then
			
			NewValue = UserDefinedEndDate;
			UserDefinedParameters["Item"].Parent.CurrentData.PlannedDate = NewValue;
			
		EndIf;
		
	Else 
		
		UserDefinedParameters["Item"].Parent.CurrentData.PlannedDate = OldValue;
		
	EndIf;
	
	OldValue = Undefined;
	
	UserDefinedSchedule.Sort("PlannedDate");
	
	SetLineNumberClient(UserDefinedSchedule);
	
EndProcedure

#EndRegion

#Region Private

#Region ManageControls

&AtServer
Procedure SetVisibleAndEnabled()
	
	Items.GroupUserDefinedHeader.ReadOnly	= ReadOnly;
	Items.UserDefinedSchedule.ReadOnly		= ReadOnly;
	
	Items.FillUserDefinedSchedule.Enabled	= Not ReadOnly;
	Items.SetPeriod.Enabled					= Not ReadOnly;
	
	If ReadOnly Then
		Items.SaveChanges.Title = NStr("en = 'Close'; ru = 'Закрыть';pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudere';de = 'Schließen'");
	EndIf;
	
EndProcedure

#EndRegion 

&AtServer
Procedure PutCustomScheduleDataInStorage()
	
	DataStructure = New Structure;
	
	DataStructure.Insert("UserDefinedStartDate",		UserDefinedStartDate);
	DataStructure.Insert("UserDefinedEndDate",			UserDefinedEndDate);
	DataStructure.Insert("UserDefinedBusinessCalendar",	UserDefinedBusinessCalendar);
	DataStructure.Insert("UserDefinedDateType",			UserDefinedDateType);
	DataStructure.Insert("UserDefinedDayOf",			UserDefinedDayOf);
	DataStructure.Insert("UserDefinedCalculateFrom",	UserDefinedCalculateFrom);
	
	TableUserDefinedSchedule = UserDefinedSchedule.Unload();
	TableUserDefinedSchedule.GroupBy("PlannedDate");
	DataStructure.Insert("UserDefinedSchedule",			TableUserDefinedSchedule);
	
	DataStructure.Insert("IsCustomScheduleChanged",	IsCustomScheduleChanged);
	
	DataAddress = PutToTempStorage(DataStructure, DataAddress);
	Modified = False;
	
EndProcedure

&AtServer
Procedure FillAtServer()
	
	UserDefinedSchedule.Clear();
	
	ValueListDaysKinds = New ValueList;
	
	If UserDefinedDateType = "Working" Then
		
		ValueListDaysKinds.Add(Enums.BusinessCalendarDaysKinds.Work);
		ValueListDaysKinds.Add(Enums.BusinessCalendarDaysKinds.Preholiday);
		
	Else 
		
		CountEnums = Enums.BusinessCalendarDaysKinds.Count();
		
		For CounterEnums = 0 To CountEnums - 1 Do
		
			ValueListDaysKinds.Add(Enums.BusinessCalendarDaysKinds.Get(CounterEnums));
		
		EndDo;
		
	EndIf;
	
	Query = New Query;
	Query.Text = GetQueryTextFillingUserDefinedSchedule(UserDefinedCalculateFrom);
	
	Query.SetParameter("BusinessCalendar", UserDefinedBusinessCalendar);
	Query.SetParameter("DayOf", UserDefinedDayOf);
	Query.SetParameter("StartDate", BegOfMonth(UserDefinedStartDate));
	Query.SetParameter("EndDate", EndOfMonth(UserDefinedEndDate));
	Query.SetParameter("ValueListDaysKinds", ValueListDaysKinds);
	
	QueryResult = Query.Execute();
	
	SelectionDates = QueryResult.Select();
	
	CounterLines = 1;
	
	While SelectionDates.Next() Do
		
		If SelectionDates.PlannedDate > UserDefinedEndDate
			Or SelectionDates.PlannedDate < UserDefinedStartDate Then
			
			Continue;
			
		EndIf;
		
		NewLineSchedule = UserDefinedSchedule.Add();
		
		NewLineSchedule.PlannedDate			= SelectionDates.PlannedDate;
		NewLineSchedule.LineNumber			= CounterLines;
		
		CounterLines = CounterLines + 1;
		
	EndDo;
	
	IsCustomScheduleChanged = True;
	
EndProcedure

&AtServerNoContext
Function GetQueryTextFillingUserDefinedSchedule(UserDefinedCalculateFrom)
	
	Result = "";
	
	If UserDefinedCalculateFrom = "Begin" Then
		
		Result = 
		"SELECT
		|	BusinessCalendarData.Date AS Date,
		|	BusinessCalendarData.DayKind AS DayKind,
		|	MONTH(BusinessCalendarData.Date) AS Month,
		|	YEAR(BusinessCalendarData.Date) AS Year
		|INTO TemporaryTable_Calendar
		|FROM
		|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
		|WHERE
		|	BusinessCalendarData.BusinessCalendar = &BusinessCalendar
		|	AND BusinessCalendarData.DayKind IN(&ValueListDaysKinds)
		|	AND BusinessCalendarData.Date BETWEEN &StartDate AND &EndDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTable_Calendar.Date AS PlannedDate
		|FROM
		|	TemporaryTable_Calendar AS TemporaryTable_Calendar
		|		INNER JOIN TemporaryTable_Calendar AS TemporaryTable_Calendar_1
		|		ON TemporaryTable_Calendar.Date >= TemporaryTable_Calendar_1.Date
		|			AND TemporaryTable_Calendar.Month = TemporaryTable_Calendar_1.Month
		|			AND TemporaryTable_Calendar.Year = TemporaryTable_Calendar_1.Year
		|
		|GROUP BY
		|	TemporaryTable_Calendar.Date,
		|	TemporaryTable_Calendar.DayKind,
		|	TemporaryTable_Calendar.Month
		|
		|HAVING
		|	COUNT(TemporaryTable_Calendar_1.Date) = &DayOf
		|
		|ORDER BY
		|	PlannedDate";
		
	Else
		
		Result = 
		"SELECT
		|	BusinessCalendarData.Date AS Date,
		|	BusinessCalendarData.DayKind AS DayKind,
		|	MONTH(BusinessCalendarData.Date) AS Month,
		|	YEAR(BusinessCalendarData.Date) AS Year
		|INTO TemporaryTable_Calendar
		|FROM
		|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
		|WHERE
		|	BusinessCalendarData.BusinessCalendar = &BusinessCalendar
		|	AND BusinessCalendarData.DayKind IN(&ValueListDaysKinds)
		|	AND BusinessCalendarData.Date BETWEEN &StartDate AND &EndDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTable_Calendar.Date AS Date,
		|	TemporaryTable_Calendar.DayKind AS DayKind,
		|	TemporaryTable_Calendar.Month AS MONTH,
		|	TemporaryTable_Calendar.Year AS Year,
		|	COUNT(TemporaryTable_Calendar_1.Date) AS LineNumber
		|INTO TemporaryTable_MonthCalendar
		|FROM
		|	TemporaryTable_Calendar AS TemporaryTable_Calendar
		|		INNER JOIN TemporaryTable_Calendar AS TemporaryTable_Calendar_1
		|		ON TemporaryTable_Calendar.Date > TemporaryTable_Calendar_1.Date
		|			AND TemporaryTable_Calendar.Month = TemporaryTable_Calendar_1.Month
		|			AND TemporaryTable_Calendar.Year = TemporaryTable_Calendar_1.Year
		|
		|GROUP BY
		|	TemporaryTable_Calendar.Date,
		|	TemporaryTable_Calendar.DayKind,
		|	TemporaryTable_Calendar.Month,
		|	TemporaryTable_Calendar.Year
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTable_MonthCalendar.MONTH AS MONTH,
		|	TemporaryTable_MonthCalendar.Year AS Year,
		|	MAX(TemporaryTable_MonthCalendar.LineNumber) + 1 AS MaxLineNumber
		|INTO TemporaryTable_MaxMonthNumber
		|FROM
		|	TemporaryTable_MonthCalendar AS TemporaryTable_MonthCalendar
		|
		|GROUP BY
		|	TemporaryTable_MonthCalendar.MONTH,
		|	TemporaryTable_MonthCalendar.Year
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTable_MonthCalendar.Date AS PlannedDate
		|FROM
		|	TemporaryTable_MonthCalendar AS TemporaryTable_MonthCalendar
		|		LEFT JOIN TemporaryTable_MaxMonthNumber AS TemporaryTable_MaxMonthNumber
		|		ON (TemporaryTable_MaxMonthNumber.MONTH = TemporaryTable_MonthCalendar.MONTH)
		|			AND (TemporaryTable_MaxMonthNumber.Year = TemporaryTable_MonthCalendar.Year)
		|WHERE
		|	TemporaryTable_MaxMonthNumber.MaxLineNumber - TemporaryTable_MonthCalendar.LineNumber = &DayOf
		|
		|ORDER BY
		|	PlannedDate";
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure CheckValueTableUserDefinedSchedule()
	
	CounterMonth	= BegOfMonth(UserDefinedStartDate);
	EndMonth		= BegOfMonth(UserDefinedEndDate);
	
	While CounterMonth <= BegOfMonth(UserDefinedEndDate) Do
		
		IsFinded = False;
		
		For Each LineSchedule In UserDefinedSchedule Do
		
			If CounterMonth = BegOfMonth(LineSchedule.PlannedDate) Then 
				IsFinded = True;
			EndIf;
			
		EndDo;
		
		If Not IsFinded Then
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The schedule excludes %1.  
					|The schedule is filled in only for the months that include a day with the specified day number and date type.'; 
					|ru = 'График исключает %1.  
					|График заполняется только для месяцев, которые включают дату с указанным числом дня и типом даты.';
					|pl = 'Harmonogram wyklucza %1.  
					|Harmonogram jest wypełniany tylko dla miesięcy, które zawierają określony numer dnia i typ rodzaj daty.';
					|es_ES = 'El horario excluye el %1. 
					|El horario se rellena sólo para los meses que incluyen un día con el número de día y el tipo fecha especificados.';
					|es_CO = 'El horario excluye el %1. 
					|El horario se rellena sólo para los meses que incluyen un día con el número de día y el tipo fecha especificados.';
					|tr = '%1 program dışında. 
					|Program sadece belirtilen gün sayısına ve gün türüne sahip bir gün içeren aylar için doldurulur.';
					|it = 'Il programma esclude %1. 
					|Il programma è compilato solo per i mesi che includono un giorno con il numero di giorno e tipo di data specificati.';
					|de = 'Der Zeitplan schließt %1 aus.  
					|Der Zeitplan wird nur für die Monate ausgefüllt, die einen Tag mit der angegebenen Tagesnummer und dem angegebenen Datumstyp enthalten.'"),
				Format(CounterMonth, "DF='MMMM yyyy'"));
			
			CommonClientServer.MessageToUser(TextMessage);
			
		EndIf;
		
		CounterMonth = BegOfMonth(AddMonth(CounterMonth, 1));
		
	EndDo;
	
EndProcedure

&AtClient
Function IsErrorsAttributesUserDefinedSchedule()
	
	Result = False;
	
	If Not ValueIsFilled(UserDefinedStartDate) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The start date is required.'; ru = 'Требуется указать дату начала.';pl = 'Wymagana jest data rozpoczęcia.';es_ES = 'Se requiere la fecha de inicio.';es_CO = 'Se requiere la fecha de inicio.';tr = 'Başlangıç tarihi gerekli.';it = 'È richiesta la data di inizio.';de = 'Das Startdatum ist erforderlich.'"), , "UserDefinedStartDate");
		Result = True;
		
	EndIf;
	
	If Not ValueIsFilled(UserDefinedEndDate) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The end date is required.'; ru = 'Требуется указать дату окончания.';pl = 'Wymagana jest data zakończenia.';es_ES = 'Se requiere la fecha final.';es_CO = 'Se requiere la fecha final.';tr = 'Bitiş tarihi gerekli.';it = 'È richiesta la data di fine.';de = 'Das Enddatum ist erforderlich.'"), , "UserDefinedEndDate");
		Result = True;
		
	EndIf;
	
	If Not ValueIsFilled(UserDefinedBusinessCalendar) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Business calendar is required.'; ru = 'Производственный календарь не заполнен.';pl = 'Wymagany jest kalendarz biznesowy.';es_ES = 'Se requiere el calendario de los días laborales.';es_CO = 'Se requiere el calendario de los días laborales.';tr = 'İş takvimi gerekli.';it = 'È richiesto il calendario aziendale.';de = 'Geschäftskalender ist erforderlich.'"), , "UserDefinedBusinessCalendar");
		Result = True;
		
	EndIf;
	
	If Not ValueIsFilled(UserDefinedDayOf) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The day number is required.'; ru = 'Требуется число дня.';pl = 'Wymagany jest numer dnia.';es_ES = 'Se requiere el número del día.';es_CO = 'Se requiere el número del día.';tr = 'Gün sayısı gerekli.';it = 'È richiesto il numero del giorno.';de = 'Die Tagesnummer ist erforderlich.'"), , "UserDefinedDayOf");
		Result = True;
		
	EndIf;
	
	If Not ValueIsFilled(UserDefinedDateType) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'The date type is required.'; ru = 'Требуется указать тип даты.';pl = 'Wymagany jest rodzaj daty.';es_ES = 'Se requiere el tipo fecha.';es_CO = 'Se requiere el tipo fecha.';tr = 'Tarih türü gerekli.';it = 'È richiesto il tipo di data.';de = 'Der Tagestyp ist erforderlich.'"), , "UserDefinedDateType");
		Result = True;
		
	EndIf;
	
	If Not ValueIsFilled(UserDefinedCalculateFrom) Then
		
		CommonClientServer.MessageToUser(NStr("en = '""from"" is required.'; ru = 'Требуется заполнить поле ""с"".';pl = 'Wymagane jest ""od"".';es_ES = 'Se requiere ""de"".';es_CO = 'Se requiere ""de"".';tr = '""başlangıç"" gerekli.';it = 'È richiesto ""da"".';de = '""vom"" ist erforderlich.'"), , "UserDefinedCalculateFrom");
		Result = True;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure ShowQueryBoxAttributesOnChange(StringNameAttribute)
	
	UserDefinedParameters = New Structure("Item", StringNameAttribute);
	Notification = New NotifyDescription("ParametersUserDefinedScheduleChanged", ThisObject, UserDefinedParameters);
	
	If IsDocumentsGenerated Then
		
		TextQuestion = NStr("en = 'Documents have already been generated according to this schedule. 
			|Changing the schedule settings can cause inconsistencies in the Generated documents summary report. 
			|Do you want to continiue?'; 
			|ru = 'Документы уже созданы в соответствии с этим графиком. 
			|Изменение настроек графика может привести к несоответствиям в сводном отчете Созданные документы. 
			|Продолжить?';
			|pl = 'Dokumenty już zostały wygenerowane zgodnie z tym harmonogramem. 
			|Zmiana ustawień harmonogramu może doprowadzić do niespójności w wygenerowanym raporcie zbiorczym dokumentów. 
			|Czy chcesz kontynuować?';
			|es_ES = 'Ya se han generado los documentos de acuerdo con este horario. 
			|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
			|¿Quiere continuar?';
			|es_CO = 'Ya se han generado los documentos de acuerdo con este horario. 
			|La modificación de las opciones del horario puede causar inconsistencias en el informe resumido de los documentos generados. 
			|¿Quiere continuar?';
			|tr = 'Bu programa göre belgeler oluşturuldu. 
			|Program ayarlarını değiştirmek oluşturulmuş belgeler özeti raporunda tutarsızlıklara yol açabilir. 
			|Devam etmek istiyor musunuz?';
			|it = 'I documenti sono stati già generati in base a questo programma. 
			|Modificare le impostazioni di programma può causare inconsistenze nel report del Riepilogo documenti generati. 
			|Continuare?';
			|de = 'Nach diesem Zeitplan wurden bereits Dokumente generiert. 
			|Das Ändern der Zeitplaneinstellungen kann zu Inkonsistenzen im Zusammenfassungsbericht „Generierte Dokumente“ führen. 
			|Möchten Sie fortsetzen?'");
		
	Else
		
		TextQuestion = NStr("en = 'The schedule will be updated. Do you want to continue?'; ru = 'График будет обновлен. Продолжить?';pl = 'Harmonogram zostanie zaktualizowany. Czy chcesz kontynuować?';es_ES = 'El horario se actualizará. ¿Quiere continuar?';es_CO = 'El horario se actualizará. ¿Quiere continuar?';tr = 'Program güncellenecek. Devam etmek istiyor musunuz?';it = 'Il programma verrà aggiornato. Continuare?';de = 'Der Zeitplan wird aktualisiert. Möchten Sie fortsetzen?'");
		
	EndIf;
	
	Mode = QuestionDialogMode.YesNo;
	ShowQueryBox(Notification, TextQuestion, Mode, 0);
	
EndProcedure

&AtServerNoContext
Function GetCurrentSessionDate()
	
	Return CurrentSessionDate();
	
EndFunction

&AtClient
Procedure SetLineNumberClient(UserDefinedSchedule)
	
	For Index = 0 To UserDefinedSchedule.Count() - 1 Do
	
		UserDefinedSchedule.Get(Index).LineNumber = Index + 1;
	
	EndDo;
	
	IsCustomScheduleChanged = True;
	
EndProcedure

&AtServerNoContext
Procedure SetLineNumber(TableUserDefinedSchedule)
	
	TableUserDefinedSchedule.Sort("PlannedDate");
	
	ArrayLines = New Array;
	
	For Counter = 1 To TableUserDefinedSchedule.Count() Do
		
		ArrayLines.Add(Counter);
		
	EndDo;
	
	TypeNumber = New TypeDescription("Number", New NumberQualifiers(4, 0, AllowedSign.Nonnegative));
	TableUserDefinedSchedule.Columns.Add("LineNumber", TypeNumber);
	
	TableUserDefinedSchedule.LoadColumn(ArrayLines, "LineNumber");
	
EndProcedure

&AtClient
Function GetDateFromStringClient(Val StringDate) 

	Result = Date(1, 1, 1);
	
	Try
	
		If StrFind(StringDate, "/") > 0 Then
			
			ArrayDate = StrSplit(StringDate, "/");
			
			Result = Date(ArrayDate[2], ArrayDate[0], ArrayDate[1]);
			
		ElsIf TrimAll(StringDate) <> "" Then
			
			Result = Date(StringDate + " 00:00:00");
			
		EndIf
		
	Except
		
		ShowMessageBox( , NStr("en = 'The date is required.'; ru = 'Требуется указать дату.';pl = 'Data jest wymagana.';es_ES = 'Se requiere la fecha.';es_CO = 'Se requiere la fecha.';tr = 'Tarih gerekli.';it = 'È richiesta la data.';de = 'Das Datum ist erforderlich.'"), 60);
		
	EndTry;
	
	Return Result;
	
EndFunction

#EndRegion