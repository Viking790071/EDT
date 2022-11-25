#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	CheckBasicCalendarUse(Cancel);
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CalendarSchedules.UpdateMultipleBusinessCalendarsUsage();
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckBasicCalendarUse(Cancel)
	
	If Ref.IsEmpty() Or Not ValueIsFilled(BasicCalendar) Then
		Return;
	EndIf;
	
	// The reference to itself is prohibited.
	If Ref = BasicCalendar Then
		MessageText = NStr("ru = 'В качестве базового не может быть выбран тот же самый календарь.'; en = 'You cannot select the same calendar as a basic calendar.'; pl = 'Jako podstawowy nie może być wybrany ten sam kalendarz.';es_ES = 'Como el calendario básico no puede ser seleccionado el mismo calendario.';es_CO = 'Como el calendario básico no puede ser seleccionado el mismo calendario.';tr = 'Aynı takvim baz takvimi olarak seçilemez.';it = 'Non potete selezionare lo stesso calendario come un calendario base.';de = 'Der gleiche Kalender kann nicht als Basiskalender ausgewählt werden.'");
		CommonClientServer.MessageToUser(MessageText, , , "Object.BasicCalendar", Cancel);
		Return;
	EndIf;
	
	// If the calendar is already a basic one for another calendar, then prohibit filling of the basic 
	// calendar to avoid cyclic dependencies.
	
	Query = New Query;
	Query.SetParameter("Calendar", Ref);
	Query.Text = 
		"SELECT TOP 1
		|	Ref
		|FROM
		|	Catalog.BusinessCalendars AS BusinessCalendars
		|WHERE
		|	BusinessCalendars.BasicCalendar = &Calendar";
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Календарь уже является базовым для календаря ""%1"" и не может зависеть от другого.'; en = 'The calendar is already a basic one for the ""%1"" calendar and it cannot depend on another calendar.'; pl = 'Kalendarz jest już podstawowym dla kalendarza ""%1"" i nie może zależeć od innego.';es_ES = 'El calendario ya es básico para el calendario ""%1"" y no puede depender de otro.';es_CO = 'El calendario ya es básico para el calendario ""%1"" y no puede depender de otro.';tr = 'Takvim ""%1"" takvimi için zaten baz takvimdir ve başka takvime bağlı olamaz.';it = 'Il calendario è di base per il calendario ""%1"" e non può dipendere da un altro calendario.';de = 'Der Kalender ist bereits grundlegend für den Kalender ""%1"" und kann nicht von anderen abhängig sein.'"),
		Selection.Ref);
	CommonClientServer.MessageToUser(MessageText, Selection.Ref, , "Object.BasicCalendar", Cancel);
	
EndProcedure

#EndRegion

#EndIf