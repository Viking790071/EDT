
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	List.Parameters.SetParameterValue("User", Users.CurrentUser());
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Items.Move(Items.CreateButton, Items.CommandBarForm);
		Items.Move(Items.ChangeButton, Items.CommandBarForm);
		Items.Move(Items.DeleteButton, Items.CommandBarForm);
		Items.Move(Items.StandardCommands, Items.CommandBarForm);
		Items.Move(Items.FormHelp, Items.CommandBarForm);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	Cancel = True;
	OpenForm("InformationRegister.UserReminders.Form.Reminder", New Structure("Key", Items.List.CurrentRow));
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	RowIsSelected = Not Item.CurrentRow = Undefined;
	Items.DeleteButton.Enabled = RowIsSelected;
	Items.ChangeButton.Enabled = RowIsSelected;
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	Cancel = True;
	DeleteReminder();
EndProcedure

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	If Field.Name = "Source" Then
		StandardProcessing = False;
		If ValueIsFilled(Items.List.CurrentData.Source) Then
			ShowValue(, Items.List.CurrentData.Source);
		Else
			ShowMessageBox(, NStr("ru = 'Источник напоминания не задан.'; en = 'Reminder source is not specified.'; pl = 'Źródło przypomnienia nie jest ustawione.';es_ES = 'La fuente de recuerdo no establecido.';es_CO = 'La fuente de recuerdo no establecido.';tr = 'Hatırlatıcı kaynağı belirlenmemiş.';it = 'La fonte del promemoria non è specificata.';de = 'Erinnerungsquelle nicht gesetzt.'"));
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Change(Command)
	OpenForm("InformationRegister.UserReminders.Form.Reminder", New Structure("Key", Items.List.CurrentRow));
EndProcedure

&AtClient
Procedure Delete(Command)
	DeleteReminder();
EndProcedure

&AtClient
Procedure Create(Command)
	OpenForm("InformationRegister.UserReminders.Form.Reminder");
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure DisableReminder(ReminderParameters)
	UserRemindersInternal.DisableReminder(ReminderParameters, False);
EndProcedure

&AtClient
Procedure DeleteReminder()
	
	DialogButtons = New ValueList;
	DialogButtons.Add(DialogReturnCode.Yes, NStr("ru = 'Удалить'; en = 'Delete'; pl = 'Usuń';es_ES = 'Borrar';es_CO = 'Borrar';tr = 'Sil';it = 'Elimina';de = 'Löschen'"));
	DialogButtons.Add(DialogReturnCode.Cancel, NStr("ru = 'Не удалять'; en = 'Do not delete'; pl = 'Nie usuwaj';es_ES = 'No borrar';es_CO = 'No borrar';tr = 'Silme';it = 'Non cancellare';de = 'Nicht löschen'"));
	NotifyDescription = New NotifyDescription("DeleteReminderCompletion", ThisObject);
	
	ShowQueryBox(NotifyDescription, NStr("ru = 'Удалить напоминание?'; en = 'Do you want to delete the reminder?'; pl = 'Usunąć przypomnienie?';es_ES = '¿Descartar el recordatorio?';es_CO = '¿Descartar el recordatorio?';tr = 'Hatırlatıcı silinsin mi?';it = 'Volete eliminare il promemoria?';de = 'Die Erinnerung ablehnen?'"), DialogButtons);
	
EndProcedure

&AtClient
Procedure DeleteReminderCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;

	RecordKey = Items.List.CurrentRow;
	ReminderParameters = New Structure("User,EventTime,Source");
	FillPropertyValues(ReminderParameters, Items.List.CurrentData);
	
	DisableReminder(ReminderParameters);
	UserRemindersClient.DeleteRecordFromNotificationsCache(ReminderParameters);
	Notify("Write_UserReminders", New Structure, RecordKey);
	NotifyChanged(Type("InformationRegisterRecordKey.UserReminders"));
	
EndProcedure

#EndRegion
