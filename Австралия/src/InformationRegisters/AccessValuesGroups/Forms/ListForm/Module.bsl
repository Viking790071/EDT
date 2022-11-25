
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
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
Procedure SetConditionalAppearance()
	
	List.SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
	
	ApplyDataGroupAppearance(0, NStr("ru = 'Стандартные значения доступа'; en = 'Standard access values'; pl = 'Domyślne wartości dostępu';es_ES = 'Valores de acceso por defecto';es_CO = 'Valores de acceso por defecto';tr = 'Varsayılan erişim değerleri';it = 'Valori di accesso predefinito';de = 'Standardzugriffswerte'"));
	ApplyDataGroupAppearance(1, NStr("ru = 'Обычные/внешние пользователи'; en = 'Regular or external users'; pl = 'Zwykli/zewnętrzni użytkownicy';es_ES = 'Usuarios estándar/externos';es_CO = 'Usuarios estándar/externos';tr = 'Standart/dış kullanıcılar';it = 'Utenti standard o esterni';de = 'Standard / externe Benutzer'"));
	ApplyDataGroupAppearance(2, NStr("ru = 'Обычные/внешние группы пользователей'; en = 'Regular or external user groups'; pl = 'Grupy zwykli/zewnętrzni użytkownicy';es_ES = 'Grupos de usuarios estándar/externos';es_CO = 'Grupos de usuarios estándar/externos';tr = 'Normal veya harici kullanıcı grupları';it = 'Gruppi utente standard o esterni';de = 'Standard / externe Benutzergruppe'"));
	ApplyDataGroupAppearance(3, NStr("ru = 'Группы исполнителей'; en = 'Assignee groups'; pl = 'Grupy wykonawców';es_ES = 'Grupos de ejecutores';es_CO = 'Grupos de ejecutores';tr = 'Icracı gruplar';it = 'Gruppi di assegnatari';de = 'Gruppen der Bevollmächtiger'"));
	ApplyDataGroupAppearance(4, NStr("ru = 'Объекты авторизации'; en = 'Authorization objects'; pl = 'Obiekty autoryzacji';es_ES = 'Objetos de autorización';es_CO = 'Objetos de autorización';tr = 'Doğrulama nesneleri';it = 'Oggetti di autorizzazione';de = 'Berechtigungsobjekte'"));
	
EndProcedure

&AtServer
Procedure ApplyDataGroupAppearance(DataGroup, Text)
	
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("DataGroup");
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("DataGroup");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = DataGroup;
	
	AppearanceItem.Appearance.SetParameterValue("Text", Text);
	
EndProcedure

&AtServer
Procedure UpdateRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.AccessValuesGroups.UpdateRegisterData(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
