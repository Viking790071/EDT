
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CanAddFromClassifier = True;
	If Not AccessRight("Insert", Metadata.Catalogs.BusinessCalendars) Then
		CanAddFromClassifier = False;
	Else
		If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
			CanAddFromClassifier = False;
		EndIf;
	EndIf;
	
	Items.FormPickFromClassifier.Visible = CanAddFromClassifier;
	If Not CanAddFromClassifier Then
		CommonClientServer.SetFormItemProperty(Items, "CreateCalendar", "Title", NStr("ru = 'Создать'; en = 'Create'; pl = 'Utwórz';es_ES = 'Crear';es_CO = 'Crear';tr = 'Oluştur';it = 'Crea';de = 'Erstellen'"));
		Items.Create.Type = FormGroupType.ButtonGroup;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Items.Move(Items.CommandBar, Items.CommandBarForm);
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBar", "Kind", FormGroupType.ButtonGroup);
		CommonClientServer.SetFormItemProperty(Items, "Create", "Picture", PictureLib.CreateListItem);
		CommonClientServer.SetFormItemProperty(Items, "Create", "Representation", ButtonRepresentation.Picture);
		CommonClientServer.SetFormItemProperty(Items, "CreateCalendar", "Picture", PictureLib.Empty);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	Items.List.Refresh();
	Items.List.CurrentRow = SelectedValue;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PickFromClassifier(Command)
	
	PickingFormName = "DataProcessor.FillCalendarSchedules.Form.PickCalendarsFromClassifier";
	OpenForm(PickingFormName, , ThisObject);
	
EndProcedure

#EndRegion
