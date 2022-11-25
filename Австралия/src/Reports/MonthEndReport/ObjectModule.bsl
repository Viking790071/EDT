#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	ReportSettings = SettingsComposer.GetSettings();
	
	ParameterBeginOfPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	ParameterEndOfPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	
	If ParameterBeginOfPeriod <> Undefined And ParameterBeginOfPeriod.Use
		And ParameterEndOfPeriod <> Undefined And ParameterEndOfPeriod.Use
		And TypeOf(ParameterBeginOfPeriod.Value) = Type("StandardBeginningDate")
		And TypeOf(ParameterEndOfPeriod.Value) = Type("StandardBeginningDate")
		And ParameterBeginOfPeriod.Value.Date <> Date(1,1,1)
		And ParameterEndOfPeriod.Value.Date <> Date(1,1,1)
		And ParameterBeginOfPeriod.Value.Date > ParameterEndOfPeriod.Value.Date Then
		
		Message = New UserMessage;
		Message.Text	 = NStr("en = 'Period start date cannot be greater than end date.'; ru = 'Дата начала периода не должна превышать дату окончания!';pl = 'Data rozpoczęcia okresu nie może przekraczać daty zakończenia.';es_ES = 'Fecha del inicio del período no puede ser superior a la fecha del fin.';es_CO = 'Fecha del inicio del período no puede ser superior a la fecha del fin.';tr = 'Dönem başlangıç tarihi bitiş tarihinden ileri olamaz.';it = 'La data di inizio periodo non può essere superiore alla data di fine.';de = 'Das Startdatum des Zeitraums darf nicht größer als das Enddatum sein.'");
		Message.Message();
		
		StandardProcessing = False;
		Return;
		
	EndIf;
	
	DCTitle = SettingsComposer.Settings.OutputParameters.Items.Find("Title");
	DCTitle.Value = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Month closing report as of %1.'; ru = 'Отчет по закрытию месяца за %1.';pl = 'Raport zamknięcia miesiąca od %1.';es_ES = 'Informe de cierre del mes como %1.';es_CO = 'Informe de cierre del mes como %1.';tr = '%1 itibariyle aylık kapanış raporu.';it = 'Report di chiusura mensile per %1.';de = 'Monatsschlussbericht zum %1.'"),
		Format(ParameterEndOfPeriod.Value, "DF='MMMM yyyy'"));
	
EndProcedure

#EndIf