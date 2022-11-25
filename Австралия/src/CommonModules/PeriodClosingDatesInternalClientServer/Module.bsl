#Region Private

////////////////////////////////////////////////////////////////////////////////
// Identical procedures and functions of PeriodClosingDates and EditPeriodEndClosingDate forms.

Function ClosingDatesDetails() Export
	
	List = New Map;
	List.Insert("",                      NStr("ru = 'Не установлена'; en = 'Not set'; pl = 'Nieustawiony';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non impostato';de = 'Nicht eingestellt'"));
	List.Insert("CustomDate",      NStr("ru = 'Произвольная дата'; en = 'Custom date'; pl = 'Dowolna data';es_ES = 'Fecha personalizada';es_CO = 'Fecha personalizada';tr = 'Özel tarih';it = 'Data personalizzata';de = 'Exaktes Datum'"));
	List.Insert("EndOfLastYear",     NStr("ru = 'Конец прошлого года'; en = 'Last year end'; pl = 'Koniec zeszłego roku';es_ES = 'Fin del año pasado';es_CO = 'Fin del año pasado';tr = 'Geçen yıl sonu';it = 'Fine dell''anno scorso';de = 'Letztes Jahresende'"));
	List.Insert("EndOfLastQuarter", NStr("ru = 'Конец прошлого квартала'; en = 'Last quarter end'; pl = 'Koniec zeszłego kwartału';es_ES = 'Fin del último trimestre';es_CO = 'Fin del último trimestre';tr = 'Geçen çeyrek sonu';it = 'Fine scorso trimestre';de = 'Letztes Quartalsende'"));
	List.Insert("EndOfLastMonth",   NStr("ru = 'Конец прошлого месяца'; en = 'Last month end'; pl = 'Koniec zeszłego miesiąca';es_ES = 'Fin del último mes';es_CO = 'Fin del último mes';tr = 'Geçen ay sonu';it = 'Fine del mese scorso';de = 'Letztes Monatsende'"));
	List.Insert("EndOfLastWeek",    NStr("ru = 'Конец прошлой недели'; en = 'Last week end'; pl = 'Koniec zeszłego tygodnia';es_ES = 'Fin de la última semana';es_CO = 'Fin de la última semana';tr = 'Geçen hafta sonu';it = 'Fine della settimana scorsa';de = 'Letzte Woche Ende'"));
	List.Insert("PreviousDay",        NStr("ru = 'Предыдущий день'; en = 'Previous day'; pl = 'Dzień poprzedni';es_ES = 'Día precedente';es_CO = 'Día precedente';tr = 'Önceki gün';it = 'Giorno precedente';de = 'Letzter Tag'"));
	
	Return List;
	
EndFunction

Procedure SpecifyPeriodEndClosingDateSetupOnChange(Context, CalculatePeriodEndClosingDate = True) Export
	
	If Context.ExtendedModeSelected Then
		If Context.PeriodEndClosingDateDetails = "" Then
			Context.PeriodEndClosingDate = "00010101";
		EndIf;
	Else
		If Context.PeriodEndClosingDate <> '00010101' AND Context.PeriodEndClosingDateDetails = "" Then
			Context.PeriodEndClosingDateDetails = "CustomDate";
			
		ElsIf Context.PeriodEndClosingDate = '00010101' AND Context.PeriodEndClosingDateDetails = "CustomDate" Then
			Context.PeriodEndClosingDateDetails = "";
		EndIf;
	EndIf;
	
	Context.RelativePeriodEndClosingDateLabelText = "";
	
	If Context.PeriodEndClosingDateDetails = "CustomDate" Or Context.PeriodEndClosingDateDetails = "" Then
		Context.PermissionDaysCount = 0;
		Return;
	EndIf;
	
	CalculatedPeriodEndClosingDates = PeriodEndClosingDateCalculation(
		Context.PeriodEndClosingDateDetails, Context.BegOfDay);
	
	If CalculatePeriodEndClosingDate Then
		Context.PeriodEndClosingDate = CalculatedPeriodEndClosingDates.Current;
	EndIf;
	
	LabelText = "";
	
	If Context.EnableDataChangeBeforePeriodEndClosingDate Then
		Days = 60*60*24;
		
		AdjustPermissionDaysCount(
			Context.PeriodEndClosingDateDetails, Context.PermissionDaysCount);
		
		PermissionPeriod = CalculatedPeriodEndClosingDates.Current + Context.PermissionDaysCount * Days;
		
		If Context.BegOfDay > PermissionPeriod Then
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Запрещен ввод и редактирование данных за все прошлые периоды 
					|по %1 включительно (%2).
					|Отсрочка, разрешавшая ввод и редактирование данных 
					|за период с %3 по %4, истекла %5.'; 
					|en = 'Data entry and editing for all previous periods 
					|up to %1 inclusive are restricted (%2).
					|Delay that allowed data entry and editing
					|for the period from %3 to %4 expired on %5.'; 
					|pl = 'Jest zakazane wprowadzenie i edycja danych za wszystkie poprzednie okresy 
					|do %1 włącznie (%2).
					| Odroczenie, pozwalające wprowadzenie i edycję danych 
					|za okres od %3 do %4, wygasło %5.';
					|es_ES = 'Está prohibido introducir o editar los datos de los períodos anteriores 
					|a %1 incluyendo (%2).
					|El aplazamiento que permitía la introducción y edición de los datos 
					|en el período de %3 a %4, está expirado %5.';
					|es_CO = 'Está prohibido introducir o editar los datos de los períodos anteriores 
					|a %1 incluyendo (%2).
					|El aplazamiento que permitía la introducción y edición de los datos 
					|en el período de %3 a %4, está expirado %5.';
					|tr = '
					| itibaren %1 kadar tüm geçmiş dönemlerde veri girişi ve düzenleme yasaktır (%2).
					|Yazılımın 
					| itibaren %3 kadar olan dönem boyunca verilerin girilmesine ve düzenlenmesine izin veren erteleme%4 süresi doldu %5.';
					|it = 'L''inserimento e la modifica dei dati per tutti i periodi precedenti
					|incluso %1 sono limitati (%2).
					|La proroga che ha consentito l''inserimento
					|e la modifica dei dati per il periodo da %3 a %4 è scaduta il %5.';
					|de = 'Es ist verboten, Daten für alle vergangenen Zeiträume
					|bis %1 einschließlich (%2) einzugeben und zu bearbeiten.
					|Die Verzögerung, die die Eingabe und Bearbeitung von Daten
					|für den Zeitraum von %3 bis %4ermöglicht, ist abgelaufen %5.'"),
				Format(Context.PeriodEndClosingDate, "DLF=D"), Lower(ClosingDatesDetails()[Context.PeriodEndClosingDateDetails]),
				Format(CalculatedPeriodEndClosingDates.Previous + Days, "DLF=D"), Format(CalculatedPeriodEndClosingDates.Current, "DLF=D"),
				Format(PermissionPeriod, "DLF=D"));
		Else
			If CalculatePeriodEndClosingDate Then
				Context.PeriodEndClosingDate = CalculatedPeriodEndClosingDates.Previous;
			EndIf;
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '• По %1 включительно запрещен ввод и редактирование данных
					|  за все прошлые периоды по %2
					|  и действует отсрочка, разрешающая ввод и редактирование данных 
					|  за период с %4 по %5;
					|• С %6 начнет действовать запрет на ввод и редактирование данных
					|  за все прошлые периоды по %5 (%3).'; 
					|en = '• You cannot enter and edit data till %1 inclusive 
					|for all previous periods up to %2; 
					|there is a delay that allows data entry and editing 
					|for the period from %4 to %5;
					|• Period-end closing becomes effective from %6 
					| for all previous periods up to %5 (%3).'; 
					|pl = '• Do %1 włącznie jest zakazane wprowadzenie i edycja danych 
					| za wszystkie poprzednie okresy według %2
					| i działa odroczenie, pozwalające wprowadzenie i edycję danych 
					| za okres od %4 do %5;
					|• Z dnia%6 zacznie obowiązywać zakaz na wprowadzenie i edycję danych 
					| za wszystkie poprzednie okresy do%5 (%3).';
					|es_ES = '• A %1 incluyendo está prohibido introducir y editar los datos 
					| de todos los períodos anteriores a %2
					| y hay aplazamiento, que permite la introducción y edición de los datos 
					| del período de %4 a %5;
					|• De %6 va a estar prohibido introducir y editar los datos
					| de todos los períodos anteriores a %5 (%3).';
					|es_CO = '• A %1 incluyendo está prohibido introducir y editar los datos 
					| de todos los períodos anteriores a %2
					| y hay aplazamiento, que permite la introducción y edición de los datos 
					| del período de %4 a %5;
					|• De %6 va a estar prohibido introducir y editar los datos
					| de todos los períodos anteriores a %5 (%3).';
					|tr = '•  %1 kadar, tüm geçmiş dönemler  %2
					|  kadar veri girişi ve düzenlenmesi 
					| yasaklanmış olup,  %4 itibaren %5 kadar veri girişine ve düzenlenmesine izin veren erteleme geçerlidir
					|;
					|•  %6 itibaren 
					| kadar tüm geçmiş dönemlere ait %5veri girişi ve düzenlenmesi yasaklanacaktır (%3).';
					|it = '• Per %1 incluso, è vietato l''inserimento e la modifica  dei dati 
					| per tutti i periodi precedenti per %2
					| ed è valido il rinvio che permette l''inserimento e la modifica dei dati 
					| per il periodo dal %4 al %5;
					|• dal %6 il divieto di inserimento e modifica dei dati 
					| diventa attivo per tutti i periodi precedenti per %5 (%3).';
					|de = '• Bis einschließlich %1 ist die Dateneingabe und -bearbeitung
					|für alle vergangenen Zeiträume bis %2
					|verboten, und es gibt eine Zurückstellung, die die Dateneingabe und -bearbeitung
					|für den Zeitraum von %4 bis %5 ermöglicht;
					|• Abschluss des Endes des Zeitraums gilt seit %6 
					|für alle vergangenen Zeiträume bis %5 (%3).'"),
					Format(PermissionPeriod, "DLF=D"), Format(Context.PeriodEndClosingDate, "DLF=D"), Lower(ClosingDatesDetails()[Context.PeriodEndClosingDateDetails]),
					Format(CalculatedPeriodEndClosingDates.Previous + Days, "DLF=D"),  Format(CalculatedPeriodEndClosingDates.Current, "DLF=D"), 
					Format(PermissionPeriod + Days, "DLF=D"));
		EndIf;
	Else
		Context.PermissionDaysCount = 0;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Запрещен ввод и редактирование данных за все прошлые периоды
			           |по %1 (%2)'; 
			           |en = 'Data entry and editing for all previous periods
			           |up to %1 (%2) are restricted'; 
			           |pl = 'Jest zakazane wprowadzenie i edycja danych za wszystkie poprzednie okresy 
			           |do %1 (%2)';
			           |es_ES = 'Está prohibido introducir y editar los datos de todos los períodos anteriores 
			           |a %1 (%2)';
			           |es_CO = 'Está prohibido introducir y editar los datos de todos los períodos anteriores 
			           |a %1 (%2)';
			           |tr = '
			           | ile %1 arasındaki tüm geçmiş dönemler için veri girişi ve düzenlenmesi yasaklanmıştır (%2)';
			           |it = 'Vietato inserimento e modifica dei dati per tutti i periodi precedenti 
			           | per %1 (%2)';
			           |de = 'Es ist verboten, Daten für alle früheren Perioden
			           |bis %1 einzugeben und zu bearbeiten (%2).'"),
			Format(Context.PeriodEndClosingDate, "DLF=D"), Lower(ClosingDatesDetails()[Context.PeriodEndClosingDateDetails]));
	EndIf;
	
	Context.RelativePeriodEndClosingDateLabelText = LabelText;
	
EndProcedure

Procedure UpdatePeriodEndClosingDateDisplayOnChange(Context) Export
	
	If Not Context.ExtendedModeSelected Then
		
		If Context.PeriodEndClosingDateDetails = "" Or Context.PeriodEndClosingDateDetails = "CustomDate" Then
			Context.ExtendedModeSelected = False;
			Context.Items.ExtendedMode.Visible = False;
			Context.Items.OperationModesGroup.CurrentPage = Context.Items.SimpleMode;
		Else
			Context.ExtendedModeSelected = True;
			Context.Items.ExtendedMode.Visible = True;
			Context.Items.OperationModesGroup.CurrentPage = Context.Items.ExtendedMode;
		EndIf;
		
	EndIf;
	 
	If Context.PeriodEndClosingDateDetails = "CustomDate" Then
		Context.Items.PeriodEndClosingDateProperties.CurrentPage = Context.Items.NoDetails;
		Context.Items.Custom.CurrentPage = Context.Items.CustomDateUsed;
		Context.EnableDataChangeBeforePeriodEndClosingDate = False;
		Return;
	EndIf;
	
	If Context.PeriodEndClosingDateDetails = "" Then
		Context.Items.PeriodEndClosingDateProperties.CurrentPage = Context.Items.NoDetails;
		Context.Items.Custom.CurrentPage = Context.Items.CustomDateNotUsed;
		Context.EnableDataChangeBeforePeriodEndClosingDate = False;
		Return;
	EndIf;
	
	Context.Items.PeriodEndClosingDateProperties.CurrentPage = Context.Items.RelativeDate;
	Context.Items.Custom.CurrentPage = Context.Items.CustomDateNotUsed;
	
	If Context.PeriodEndClosingDateDetails = "PreviousDay" Then
		Context.Items.EnableDataChangeBeforePeriodEndClosingDate.Enabled = False;
		Context.EnableDataChangeBeforePeriodEndClosingDate = False;
	Else
		Context.Items.EnableDataChangeBeforePeriodEndClosingDate.Enabled = True;
	EndIf;
	
	Context.Items.PermissionDaysCount.Enabled = Context.EnableDataChangeBeforePeriodEndClosingDate;
	Context.Items.NoncustomDateNote.Title = Context.RelativePeriodEndClosingDateLabelText;
	
EndProcedure

Function PeriodEndClosingDateCalculation(Val PeriodEndClosingDateOption, Val CurrentDateAtServer)
	
	Days = 60*60*24;
	
	CurrentPeriodEndClosingDate    = '00010101';
	PreviousPeriodEndClosingDate = '00010101';
	
	If PeriodEndClosingDateOption = "EndOfLastYear" Then
		CurrentPeriodEndClosingDate    = BegOfYear(CurrentDateAtServer) - Days;
		PreviousPeriodEndClosingDate = BegOfYear(CurrentPeriodEndClosingDate)   - Days;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastQuarter" Then
		CurrentPeriodEndClosingDate    = BegOfQuarter(CurrentDateAtServer) - Days;
		PreviousPeriodEndClosingDate = BegOfQuarter(CurrentPeriodEndClosingDate)   - Days;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastMonth" Then
		CurrentPeriodEndClosingDate    = BegOfMonth(CurrentDateAtServer) - Days;
		PreviousPeriodEndClosingDate = BegOfMonth(CurrentPeriodEndClosingDate)   - Days;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastWeek" Then
		CurrentPeriodEndClosingDate    = BegOfWeek(CurrentDateAtServer) - Days;
		PreviousPeriodEndClosingDate = BegOfWeek(CurrentPeriodEndClosingDate)   - Days;
		
	ElsIf PeriodEndClosingDateOption = "PreviousDay" Then
		CurrentPeriodEndClosingDate    = BegOfDay(CurrentDateAtServer) - Days;
		PreviousPeriodEndClosingDate = BegOfDay(CurrentPeriodEndClosingDate)   - Days;
	EndIf;
	
	Return New Structure("Current, Previous", CurrentPeriodEndClosingDate, PreviousPeriodEndClosingDate);
	
EndFunction

Procedure AdjustPermissionDaysCount(Val PeriodEndClosingDateDetails, PermissionDaysCount)
	
	If PermissionDaysCount = 0 Then
		PermissionDaysCount = 1;
		
	ElsIf PeriodEndClosingDateDetails = "EndOfLastYear" Then
		If PermissionDaysCount > 90 Then
			PermissionDaysCount = 90;
		EndIf;
		
	ElsIf PeriodEndClosingDateDetails = "EndOfLastQuarter" Then
		If PermissionDaysCount > 60 Then
			PermissionDaysCount = 60;
		EndIf;
		
	ElsIf PeriodEndClosingDateDetails = "EndOfLastMonth" Then
		If PermissionDaysCount > 25 Then
			PermissionDaysCount = 25;
		EndIf;
		
	ElsIf PeriodEndClosingDateDetails = "EndOfLastWeek" Then
		If PermissionDaysCount > 5 Then
			PermissionDaysCount = 5;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
