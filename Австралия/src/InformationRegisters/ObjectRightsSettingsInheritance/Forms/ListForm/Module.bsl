
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateRegisterData(Command)
	
	HasChanges = False;
	
	UpdateRegisterDataAtServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("ru = 'Обновление выполнено успешно.'; en = 'The update is completed.'; pl = 'Aktualizacja zakończona pomyślnie.';es_ES = 'Actualización se ha realizado con éxito.';es_CO = 'Actualización se ha realizado con éxito.';tr = 'Güncelleme başarılı.';it = 'L''aggiornamento è stato completato.';de = 'Das Update war erfolgreich.'");
	Else
		Text = NStr("ru = 'Обновление не требуется.'; en = 'The update is not required.'; pl = 'Aktualizacja nie jest wymagana.';es_ES = 'No se requiere una actualización.';es_CO = 'No se requiere una actualización.';tr = 'Güncelleme gerekmiyor.';it = 'L''aggiornamento non è richiesto';de = 'Update ist nicht erforderlich.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.ObjectRightsSettingsInheritance.UpdateRegisterData(, HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
