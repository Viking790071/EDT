#Region Variables

&AtClient
Var ActionSelected;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;

	InitialValue = Parameters.InitialValue;
	
	If Not ValueIsFilled(InitialValue) Then
		InitialValue = CurrentSessionDate();
	EndIf;
	
	Parameters.Property("BeginOfRepresentationPeriod", Items.Calendar.BeginOfRepresentationPeriod);
	Parameters.Property("EndOfRepresentationPeriod", Items.Calendar.EndOfRepresentationPeriod);
	
	Calendar = InitialValue;
	
	Parameters.Property("Title", Title);
	
	If Parameters.Property("NoteText") Then
		Items.NoteText.Title = Parameters.NoteText;
	Else
		Items.NoteText.Visible = False;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	If ActionSelected <> True Then
		NotifyChoice(Undefined);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CalendarChoice(Item, SelectedDate)
	
	ActionSelected = True;
	NotifyChoice(SelectedDate);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() = 0 Then
		ShowMessageBox(,NStr("ru = 'Дата не выбрана.'; en = 'The date is not selected.'; pl = 'Data nie jest wybrana.';es_ES = 'Fecha no está seleccionada.';es_CO = 'Fecha no está seleccionada.';tr = 'Tarih seçilmedi.';it = 'Data non selezionata.';de = 'Datum ist nicht ausgewählt.'"));
		Return;
	EndIf;
	
	ActionSelected = True;
	NotifyChoice(SelectedDates[0]);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ActionSelected = True;
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

